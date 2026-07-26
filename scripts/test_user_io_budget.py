import datetime as dt
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).with_name("user_io_budget.py")
SPEC = importlib.util.spec_from_file_location("user_io_budget", SCRIPT)
BUDGET = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUDGET)


class BudgetTestCase(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.cgroup_root = self.root / "cgroup"
        self.cgroup = self.cgroup_root / "user.slice" / "user-1002.slice"
        self.cgroup.mkdir(parents=True)
        (self.cgroup / "io.max").write_text("259:0 rbps=max wbps=max riops=max wiops=max\n")
        self.state = self.root / "state.json"
        self.metrics = self.root / "metrics.prom"
        self.config = {
            "devices": ["/dev/fake"],
            "users": [{"name": "siraben", "uid": 1002, "daily_bytes": 1000}],
            "daily_bytes": 1000,
            "burst_bps": 200,
            "exhausted_bps": 10,
            "warning_percentages": [50, 75, 90],
            "terminal_notifications": True,
        }
        self.device_patch = mock.patch.object(
            BUDGET,
            "resolve_devices",
            return_value=[{"path": "/dev/fake", "major_minor": "259:0"}],
        )
        self.device_patch.start()
        self.notifications = []
        self.notification_patch = mock.patch.object(
            BUDGET,
            "notify_user_terminals",
            side_effect=lambda uid, message: self.notifications.append((uid, message)) or 1,
        )
        self.notification_patch.start()
        self.fake_systemd = lambda _unit, devices, rate: (self.cgroup / "io.max").write_text(
            "".join(
                f"{device['major_minor']} rbps=max wbps={rate} riops=max wiops=max\n"
                for device in devices
            )
        )
        self.systemd_patch = mock.patch.object(
            BUDGET,
            "set_systemd_write_limit",
            side_effect=self.fake_systemd,
        )
        self.systemd_mock = self.systemd_patch.start()

    def tearDown(self):
        self.systemd_patch.stop()
        self.notification_patch.stop()
        self.device_patch.stop()
        self.temporary.cleanup()

    def write_counter(self, value):
        (self.cgroup / "io.stat").write_text(
            f"259:0 rbytes=0 wbytes={value} rios=0 wios=1 dbytes=0 dios=0\n"
        )

    def sample(self, counter, now):
        self.write_counter(counter)
        return BUDGET.run_once(
            self.config,
            self.state,
            self.metrics,
            self.cgroup_root,
            now=now,
        )[0]

    def local_timestamp(self, year, month, day, hour, minute):
        local = dt.datetime(year, month, day, hour, minute).astimezone()
        return local.timestamp()

    def test_first_sample_establishes_baseline(self):
        result = self.sample(500, self.local_timestamp(2026, 7, 23, 12, 0))
        self.assertEqual(result["used"], 0)
        self.assertFalse(result["throttled"])
        self.assertIn("wbps=200", (self.cgroup / "io.max").read_text())
        self.assertIn("user_io_budget_used_bytes", self.metrics.read_text())

    def test_thresholds_notify_once_and_exhaustion_throttles(self):
        start = self.local_timestamp(2026, 7, 23, 12, 0)
        self.sample(100, start)
        first = self.sample(950, start + 600)
        self.assertEqual(first["used"], 850)
        self.assertEqual(len(self.notifications), 2)
        self.assertIn("50%", self.notifications[0][1])
        self.assertIn("75%", self.notifications[1][1])

        second = self.sample(1000, start + 1200)
        self.assertEqual(second["used"], 900)
        self.assertEqual(len(self.notifications), 3)
        self.assertIn("90%", self.notifications[2][1])

        exhausted = self.sample(1150, start + 1800)
        self.assertEqual(exhausted["used"], 1050)
        self.assertTrue(exhausted["throttled"])
        self.assertEqual(len(self.notifications), 4)
        self.assertIn("exhausted", self.notifications[3][1])
        self.assertIn("wbps=10", (self.cgroup / "io.max").read_text())

        self.sample(1200, start + 2400)
        self.assertEqual(len(self.notifications), 4)

    def test_counter_reset_is_counted_conservatively(self):
        start = self.local_timestamp(2026, 7, 23, 12, 0)
        self.sample(1000, start)
        self.assertEqual(self.sample(1200, start + 600)["used"], 200)
        self.assertEqual(self.sample(50, start + 1200)["used"], 250)

    def test_boot_change_counts_the_new_counter_from_zero(self):
        start = self.local_timestamp(2026, 7, 23, 12, 0)
        self.sample(100, start)
        self.assertEqual(self.sample(200, start + 600)["used"], 100)
        state = json.loads(self.state.read_text())
        state["boot_id"] = "previous-boot"
        self.state.write_text(json.dumps(state))
        self.assertEqual(self.sample(300, start + 1200)["used"], 400)

    def test_midnight_charges_the_crossing_interval_to_the_new_day(self):
        before = self.local_timestamp(2026, 7, 23, 23, 55)
        after = self.local_timestamp(2026, 7, 24, 0, 5)
        self.sample(100, before - 600)
        self.sample(200, before)
        result = self.sample(300, after)
        self.assertEqual(result["used"], 100)
        state = json.loads(self.state.read_text())
        self.assertEqual(state["day"], "2026-07-24")
        self.assertEqual(state["users"]["1002"]["warned"], [])

    def test_missing_cgroup_preserves_usage(self):
        start = self.local_timestamp(2026, 7, 23, 12, 0)
        self.sample(100, start)
        self.assertEqual(self.sample(400, start + 600)["used"], 300)
        for child in self.cgroup.iterdir():
            child.unlink()
        self.cgroup.rmdir()
        result = BUDGET.run_once(
            self.config,
            self.state,
            self.metrics,
            self.cgroup_root,
            now=start + 1200,
        )[0]
        self.assertEqual(result["used"], 300)
        self.assertFalse(result["active"])

    def test_corrupt_state_fails_closed(self):
        self.state.write_text("not json")
        result = self.sample(100, self.local_timestamp(2026, 7, 23, 12, 0))
        self.assertEqual(result["used"], 1000)
        self.assertTrue(result["throttled"])
        self.assertIn("wbps=10", (self.cgroup / "io.max").read_text())
        self.assertEqual(len(self.notifications), 1)
        self.assertIn("exhausted", self.notifications[0][1])

    def test_structurally_invalid_state_fails_closed(self):
        self.state.write_text(json.dumps({"version": 1, "day": "2026-07-23", "users": {"1002": {}}}))
        result = self.sample(100, self.local_timestamp(2026, 7, 23, 12, 0))
        self.assertEqual(result["used"], 1000)
        self.assertTrue(result["throttled"])

    def test_duplicate_uid_configuration_is_rejected(self):
        self.config["users"].append({"name": "other", "uid": 1002, "daily_bytes": 1000})
        self.write_counter(100)
        with self.assertRaisesRegex(ValueError, "UIDs"):
            BUDGET.run_once(
                self.config,
                self.state,
                self.metrics,
                self.cgroup_root,
                now=self.local_timestamp(2026, 7, 23, 12, 0),
            )

    def test_two_device_deltas_are_aggregated(self):
        start = self.local_timestamp(2026, 7, 23, 12, 0)
        devices = [
            {"path": "/dev/a", "major_minor": "259:0"},
            {"path": "/dev/b", "major_minor": "259:1"},
        ]
        with mock.patch.object(BUDGET, "resolve_devices", return_value=devices), mock.patch.object(
            BUDGET, "apply_write_limit", return_value=False
        ):
            (self.cgroup / "io.stat").write_text("259:0 wbytes=100\n259:1 wbytes=200\n")
            BUDGET.run_once(self.config, self.state, self.metrics, self.cgroup_root, now=start)
            (self.cgroup / "io.stat").write_text("259:0 wbytes=150\n259:1 wbytes=260\n")
            result = BUDGET.run_once(self.config, self.state, self.metrics, self.cgroup_root, now=start + 600)[0]
        self.assertEqual(result["used"], 110)

    def test_boot_change_remains_pending_while_slice_is_absent(self):
        start = self.local_timestamp(2026, 7, 23, 12, 0)
        self.sample(100, start)
        self.assertEqual(self.sample(200, start + 600)["used"], 100)
        state = json.loads(self.state.read_text())
        state["boot_id"] = "previous-boot"
        self.state.write_text(json.dumps(state))
        for child in self.cgroup.iterdir():
            child.unlink()
        self.cgroup.rmdir()
        BUDGET.run_once(self.config, self.state, self.metrics, self.cgroup_root, now=start + 1200)
        state = json.loads(self.state.read_text())
        self.assertNotIn("inode", state["users"]["1002"])
        self.assertNotIn("counters", state["users"]["1002"])
        self.cgroup.mkdir()
        (self.cgroup / "io.max").write_text("259:0 rbps=max wbps=max riops=max wiops=max\n")
        self.assertEqual(self.sample(300, start + 1800)["used"], 400)

    def test_enforcement_failure_does_not_emit_uncommitted_warnings(self):
        start = self.local_timestamp(2026, 7, 23, 12, 0)
        self.sample(100, start)
        self.systemd_mock.side_effect = RuntimeError("injected enforcement failure")
        with self.assertRaisesRegex(RuntimeError, "injected"):
            self.sample(1200, start + 600)
        self.assertEqual(self.notifications, [])
        self.systemd_mock.side_effect = self.fake_systemd
        result = self.sample(1200, start + 1200)
        self.assertTrue(result["throttled"])
        self.assertEqual(len(self.notifications), 4)

    def test_backward_date_does_not_grant_a_new_budget(self):
        later = self.local_timestamp(2026, 7, 24, 12, 0)
        earlier = self.local_timestamp(2026, 7, 23, 12, 0)
        self.sample(100, later)
        self.assertEqual(self.sample(400, later + 600)["used"], 300)
        result = self.sample(500, earlier)
        self.assertEqual(result["used"], 400)
        state = json.loads(self.state.read_text())
        self.assertEqual(state["day"], "2026-07-24")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Behavior tests for the bounded IronMain CI slot allocator."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).parent))

from ironmain_ci_slots import (  # noqa: E402
    ArtifactRole,
    Compatibility,
    LeaseIdentity,
    Liveness,
    MeteredCommandResult,
    ProcessOwner,
    RegisteredResourceKind,
    ResourceRegistry,
    RoleBusy,
    SlotAllocator,
    SlotId,
    SlotUnavailable,
    TelemetryAvailability,
    UnsafeIdentity,
    _owner_liveness,
    _reference_liveness,
    redact_secrets,
)


class SlotAllocatorTests(unittest.TestCase):
    """Exercise fixed slot, role, trust, and pressure invariants."""

    # /// What it's testing: The allocator creates exactly twelve fixed slots and no identity-derived roots.
    # /// Why it matters: Fixed cardinality prevents per-job and per-commit cache generations from growing without bound.
    def test_layout_has_exactly_twelve_fixed_slots(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()

            self.assertEqual(
                tuple(range(12)),
                tuple(slot.value for slot in allocator.layout.slot_ids),
            )
            self.assertEqual(
                [f"{index:02d}" for index in range(12)],
                sorted(path.name for path in allocator.layout.slots_root.iterdir()),
            )
            with self.assertRaises(ValueError):
                SlotId(12)
            self.assertFalse(
                any(
                    "commit" in path.name or "job" in path.name
                    for path in Path(directory).rglob("*")
                )
            )

    # /// What it's testing: Twelve simultaneous callers receive distinct leases and a thirteenth is rejected.
    # /// Why it matters: Workspaces must be private without silently exceeding configured runner capacity.
    def test_concurrent_callers_receive_distinct_leases_and_thirteenth_fails(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            leases = [
                allocator.acquire(LeaseIdentity("runner", "ironmain", "trusted"))
                for _ in range(12)
            ]
            self.addCleanup(lambda: [lease.release() for lease in leases])

            self.assertEqual(12, len({lease.slot_id for lease in leases}))
            with self.assertRaises(SlotUnavailable):
                allocator.acquire(LeaseIdentity("runner", "ironmain", "trusted"))

    # /// What it's testing: Role roots are fixed, separate, exclusive, and preserve compatible clean artifacts.
    # /// Why it matters: Standard and both coverage builds must never race on shared mutable Cargo state.
    def test_roles_are_separate_exclusive_and_compatibility_reused(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            compatibility = Compatibility(
                "tool",
                "lock",
                "cargo",
                "flags",
                "profile",
                ("pkg",),
                ("feat",),
                "filter",
                "script",
            )
            roots = {
                role: allocator.layout.role_root(SlotId(0), role)
                for role in ArtifactRole
            }
            self.assertEqual(3, len(set(roots.values())))

            identity = LeaseIdentity("runner", "ironmain", "trusted")
            first = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, identity
            )
            (first.root / "warm-artifact").write_text("warm")
            with self.assertRaises(RoleBusy):
                allocator.acquire_role(
                    SlotId(0), ArtifactRole.STANDARD, compatibility, identity
                )
            first.release(clean=True)

            second = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, identity
            )
            self.assertTrue(second.reused)
            self.assertTrue((second.root / "warm-artifact").exists())
            second.release(clean=True)

    # /// What it's testing: Dirty and incompatible unlocked roles recycle in place without changing their path.
    # /// Why it matters: Recovery must remove poisoned artifacts without recreating source-keyed target directories.
    def test_dirty_and_incompatible_roles_recycle_in_place(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            original = Compatibility(
                "tool-a",
                "lock",
                "cargo",
                "flags",
                "profile",
                (),
                (),
                "filter",
                "script",
            )
            changed = Compatibility(
                "tool-b",
                "lock",
                "cargo",
                "flags",
                "profile",
                (),
                (),
                "filter",
                "script",
            )

            identity = LeaseIdentity("runner", "ironmain", "trusted")
            dirty = allocator.acquire_role(
                SlotId(0), ArtifactRole.COVERAGE_BASELINE, original, identity
            )
            root = dirty.root
            (root / "poison").write_text("partial")
            dirty.release(clean=False)
            recovered = allocator.acquire_role(
                SlotId(0), ArtifactRole.COVERAGE_BASELINE, original, identity
            )
            self.assertEqual(root, recovered.root)
            self.assertFalse(recovered.reused)
            self.assertFalse((root / "poison").exists())
            (root / "old").write_text("old")
            recovered.release(clean=True)

            invalidated = allocator.acquire_role(
                SlotId(0), ArtifactRole.COVERAGE_BASELINE, changed, identity
            )
            self.assertEqual(root, invalidated.root)
            self.assertFalse(invalidated.reused)
            self.assertFalse((root / "old").exists())
            invalidated.release(clean=True)

    # /// What it's testing: Compatible role artifacts do not cross validated user or fork trust namespaces.
    # /// Why it matters: Shared runner storage must not allow one caller to consume another caller's mutable outputs.
    def test_role_reuse_is_isolated_by_trust_namespace(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            compatibility = Compatibility(
                "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
            )
            trusted = LeaseIdentity("runner", "ironmain", "trusted")
            forked = LeaseIdentity("contributor", "ironmain", "fork-42")
            first = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, trusted
            )
            (first.root / "trusted-artifact").write_text("trusted")
            first.release(clean=True)

            isolated = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, forked
            )
            self.assertFalse(isolated.reused)
            self.assertFalse((isolated.root / "trusted-artifact").exists())
            isolated.release(clean=True)

    # /// What it's testing: Stable workspaces reference one read-only mirror through Git alternates.
    # /// Why it matters: Jobs must not duplicate checkout object trees or gain mirror write access.
    def test_workspaces_reference_job_read_only_mirror(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()

            self.assertEqual(0o550, allocator.layout.mirror_root.stat().st_mode & 0o777)
            for slot_id in allocator.layout.slot_ids:
                for workspace in ("head", "baseline"):
                    root = allocator.layout.workspace_root(slot_id, workspace)
                    alternates = root / ".git" / "objects" / "info" / "alternates"
                    self.assertEqual(
                        str(allocator.layout.mirror_root / "objects"),
                        alternates.read_text().strip(),
                    )
                    self.assertFalse((root / ".git" / "objects" / "pack").exists())

    # /// What it's testing: Unsafe cross-user, fork, repository, and credential-bearing identities are rejected or redacted.
    # /// Why it matters: Persistent shared state must not permit cache poisoning or credential disclosure.
    def test_identity_boundaries_and_redaction(self) -> None:
        for values in (
            ("../root", "ironmain", "trusted"),
            ("runner", "../ironmain", "trusted"),
            ("runner", "ironmain", "fork/../../owner"),
            ("https://user:secret@example.test", "ironmain", "trusted"),
        ):
            with self.subTest(values=values), self.assertRaises(UnsafeIdentity):
                LeaseIdentity(*values)

        message = "clone https://alice:hunter2@example.test/repo TOKEN=abc123 Authorization: Bearer xyz"
        redacted = redact_secrets(message)
        self.assertNotIn("hunter2", redacted)
        self.assertNotIn("abc123", redacted)
        self.assertNotIn("xyz", redacted)
        self.assertIn("[REDACTED]", redacted)

    # /// What it's testing: Slot state heartbeat updates atomically and cancellation leaves a recoverable unlocked slot.
    # /// Why it matters: Interrupted jobs must not strand capacity or expose partially written state.
    def test_heartbeat_and_cancelled_lease_recover(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            lease = allocator.acquire(LeaseIdentity("runner", "ironmain", "trusted"))
            lease.heartbeat()
            state_path = allocator.layout.slot_state(lease.slot_id)
            state = json.loads(state_path.read_text())
            self.assertEqual("active", state["state"])
            self.assertGreater(state["heartbeat_ns"], 0)
            lease.release(cancelled=True)
            recovered = allocator.acquire(
                LeaseIdentity("runner", "ironmain", "trusted")
            )
            self.assertEqual(lease.slot_id, recovered.slot_id)
            recovered.release()

    # /// What it's testing: Pressure eviction skips active roles and removes unlocked least-recently-used artifacts only across 15/20 thresholds.
    # /// Why it matters: Disk pressure must preserve live builds while bounding retained artifacts predictably.
    def test_pressure_evicts_unlocked_lru_until_twenty_percent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            compatibility = Compatibility(
                "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
            )
            identity = LeaseIdentity("runner", "ironmain", "trusted")
            old = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, identity
            )
            (old.root / "artifact").write_text("old")
            old.release(clean=True, last_used_ns=10)
            newer = allocator.acquire_role(
                SlotId(1), ArtifactRole.STANDARD, compatibility, identity
            )
            (newer.root / "artifact").write_text("new")
            newer.release(clean=True, last_used_ns=20)
            active = allocator.acquire_role(
                SlotId(2), ArtifactRole.STANDARD, compatibility, identity
            )
            (active.root / "artifact").write_text("active")
            percentages = iter((10.0, 16.0, 21.0))

            evicted = allocator.evict_under_pressure(lambda: next(percentages))

            self.assertEqual(
                [
                    (SlotId(0), ArtifactRole.STANDARD),
                    (SlotId(1), ArtifactRole.STANDARD),
                ],
                evicted,
            )
            self.assertTrue((active.root / "artifact").exists())
            active.release(clean=True)

    # /// What it's testing: Eviction does nothing at or above the fifteen-percent trigger.
    # /// Why it matters: Healthy compatible artifacts must not be churned without actual pressure.
    def test_pressure_does_not_evict_at_threshold(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            self.assertEqual([], allocator.evict_under_pressure(lambda: 15.0))

    # /// What it's testing: A slot lease protects its unlocked role artifacts from pressure eviction.
    # /// Why it matters: Active jobs may pause between role operations without forfeiting their warm artifacts.
    def test_pressure_preserves_every_role_in_an_active_slot(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            identity = LeaseIdentity("runner", "ironmain", "trusted")
            compatibility = Compatibility(
                "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
            )
            evictable = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, identity
            )
            (evictable.root / "artifact").write_text("evictable")
            evictable.release(clean=True, last_used_ns=10)
            active_artifact = allocator.acquire_role(
                SlotId(1), ArtifactRole.STANDARD, compatibility, identity
            )
            (active_artifact.root / "artifact").write_text("active")
            active_artifact.release(clean=True, last_used_ns=1)
            active_slot = allocator.acquire(identity)
            self.assertEqual(SlotId(0), active_slot.slot_id)
            # Keep slot 01 active as well so its older artifact must be skipped.
            second_active_slot = allocator.acquire(identity)
            self.assertEqual(SlotId(1), second_active_slot.slot_id)
            percentages = iter((10.0, 21.0))

            evicted = allocator.evict_under_pressure(lambda: next(percentages))

            self.assertEqual([], evicted)
            self.assertTrue((active_artifact.root / "artifact").exists())
            second_active_slot.release()
            active_slot.release()

    # /// What it's testing: Pressure eviction preserves roles whose registration state is malformed or uncertain.
    # /// Why it matters: Corrupt metadata must fail closed instead of authorizing deletion of potentially live artifacts.
    def test_pressure_preserves_malformed_registration_state(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            root = allocator.layout.role_root(SlotId(0), ArtifactRole.STANDARD)
            (root / "artifact").write_text("preserve")
            allocator.layout.role_state(SlotId(0), ArtifactRole.STANDARD).write_text(
                "not-json"
            )

            self.assertEqual([], allocator.evict_under_pressure(lambda: 1.0))
            self.assertTrue((root / "artifact").exists())

    # /// What it's testing: An externally held role lock is treated as active during pressure handling.
    # /// Why it matters: Eviction must fail closed even when the active owner is another process.
    def test_pressure_preserves_external_lock_holder(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            compatibility = Compatibility(
                "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
            )
            role = allocator.acquire_role(
                SlotId(0),
                ArtifactRole.COVERAGE_CURRENT,
                compatibility,
                LeaseIdentity("runner", "ironmain", "trusted"),
            )
            (role.root / "artifact").write_text("active")
            percentages = iter((1.0, 20.0))
            self.assertEqual(
                [], allocator.evict_under_pressure(lambda: next(percentages))
            )
            self.assertTrue((role.root / "artifact").exists())
            role.release(clean=True)

    # /// What it's testing: Metering keeps unavailable physical I/O as null and emits only safe typed state.
    # /// Why it matters: Missing cgroup counters must never be misreported as authoritative zero or leak secrets.
    def test_metered_result_models_unavailable_io_as_null_and_redacts_state(self) -> None:
        result = MeteredCommandResult.unavailable(
            invocation_id="run-1",
            elapsed_seconds=1.25,
            artifact_bytes=42,
            diagnostic="https://alice:hunter2@example.test token=abc",
        )

        state = result.to_state()

        self.assertEqual(TelemetryAvailability.UNAVAILABLE.value, state["telemetry"])
        self.assertIsNone(state["physical_read_bytes"])
        self.assertIsNone(state["physical_write_bytes"])
        self.assertNotIn("hunter2", json.dumps(state))
        self.assertNotIn("abc", json.dumps(state))
        with self.assertRaises(ValueError):
            MeteredCommandResult(
                invocation_id="run-2",
                telemetry=TelemetryAvailability.AVAILABLE,
                physical_read_bytes=None,
                physical_write_bytes=0,
                elapsed_seconds=0.0,
                artifact_bytes=0,
                diagnostic="",
            )

    # /// What it's testing: Cleanup removes a stale registered resource only after every liveness check is negative.
    # /// Why it matters: Cleanup needs positive registration and fail-closed proof before deleting abandoned targets.
    def test_cleanup_removes_only_registered_resource_after_negative_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            allowed = root / "targets"
            allowed.mkdir()
            abandoned = allowed / "abandoned"
            abandoned.mkdir()
            (abandoned / "artifact").write_text("old")
            unrelated = allowed / "unregistered"
            unrelated.mkdir()
            registry = ResourceRegistry(
                root / "registry",
                (allowed,),
                monotonic_ns=lambda: 1_000,
                owner_liveness=lambda owner: Liveness.DEAD,
                reference_liveness=lambda path: Liveness.DEAD,
                heartbeat_timeout_ns=100,
            )
            registry.register(
                "resource-1",
                RegisteredResourceKind.CARGO_TARGET,
                abandoned,
                ProcessOwner(1234, 5678),
                heartbeat_ns=1,
            )

            removed = registry.cleanup_stale()

            self.assertEqual(("resource-1",), removed)
            self.assertFalse(abandoned.exists())
            self.assertTrue(unrelated.exists())

    # /// What it's testing: Cleanup preserves resources when heartbeat, owner, cwd/fd, or lock evidence is live or uncertain.
    # /// Why it matters: Any uncertainty or active reference must prevent destructive stale-resource cleanup.
    def test_cleanup_fails_closed_for_each_liveness_and_lock_signal(self) -> None:
        cases = (
            ("heartbeat-live", 950, Liveness.DEAD, Liveness.DEAD, False),
            ("owner-live", 1, Liveness.LIVE, Liveness.DEAD, False),
            ("owner-uncertain", 1, Liveness.UNCERTAIN, Liveness.DEAD, False),
            ("reference-live", 1, Liveness.DEAD, Liveness.LIVE, False),
            ("reference-uncertain", 1, Liveness.DEAD, Liveness.UNCERTAIN, False),
            ("lock-live", 1, Liveness.DEAD, Liveness.DEAD, True),
        )
        for resource_id, heartbeat, owner_state, reference_state, hold_lock in cases:
            with self.subTest(resource_id=resource_id), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                allowed = root / "targets"
                resource = allowed / resource_id
                resource.mkdir(parents=True)
                registry = ResourceRegistry(
                    root / "registry",
                    (allowed,),
                    monotonic_ns=lambda: 1_000,
                    owner_liveness=lambda owner, state=owner_state: state,
                    reference_liveness=lambda path, state=reference_state: state,
                    heartbeat_timeout_ns=100,
                )
                registry.register(
                    resource_id,
                    RegisteredResourceKind.WORKTREE,
                    resource,
                    ProcessOwner(1234, 5678),
                    heartbeat_ns=heartbeat,
                )
                held = registry.acquire_resource_lock(resource_id) if hold_lock else None
                try:
                    self.assertEqual((), registry.cleanup_stale())
                    self.assertTrue(resource.exists())
                finally:
                    if held is not None:
                        held.release()

    # /// What it's testing: Procfs probes distinguish PID reuse and detect cwd and open-fd references.
    # /// Why it matters: Cleanup must independently prove owner exit and absence of process references before deletion.
    def test_procfs_owner_cwd_and_fd_liveness_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proc = root / "proc"
            process = proc / "123"
            (process / "fd").mkdir(parents=True)
            resource = root / "target"
            resource.mkdir()
            (process / "stat").write_text("123 (runner task) S " + "0 " * 18 + "5678 0\n")

            self.assertEqual(
                Liveness.LIVE,
                _owner_liveness(ProcessOwner(123, 5678), proc),
            )
            self.assertEqual(
                Liveness.DEAD,
                _owner_liveness(ProcessOwner(123, 9999), proc),
            )
            (process / "cwd").symlink_to(resource)
            self.assertEqual(Liveness.LIVE, _reference_liveness(resource, proc))
            (process / "cwd").unlink()
            (process / "cwd").symlink_to(root)
            (process / "fd" / "4").symlink_to(resource / "artifact")
            self.assertEqual(Liveness.LIVE, _reference_liveness(resource, proc))

    # /// What it's testing: Registration rejects traversal, allowed-root deletion, unsafe IDs, and credential-bearing paths.
    # /// Why it matters: A poisoned registry must not turn targeted cleanup into arbitrary filesystem deletion or secret persistence.
    def test_cleanup_registration_rejects_unsafe_or_overbroad_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            allowed = root / "targets"
            allowed.mkdir()
            registry = ResourceRegistry(root / "registry", (allowed,))
            owner = ProcessOwner(1234, 5678)

            for resource_id, path in (
                ("../escape", allowed / "safe"),
                ("allowed-root", allowed),
                ("outside", root / "outside"),
                ("credential", allowed / "token=secret"),
            ):
                with self.subTest(resource_id=resource_id), self.assertRaises(ValueError):
                    registry.register(
                        resource_id,
                        RegisteredResourceKind.STAGING,
                        path,
                        owner,
                        heartbeat_ns=1,
                    )


if __name__ == "__main__":
    unittest.main()

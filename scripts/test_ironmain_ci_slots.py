#!/usr/bin/env python3
"""Behavior tests for the bounded IronMain CI slot allocator."""

from __future__ import annotations

import json
import os
from pathlib import Path
import pwd
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))

import ironmain_ci_slots as slots  # noqa: E402
from ironmain_ci_slots import (  # noqa: E402
    ArtifactRole,
    CgroupScope,
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
    render_prometheus_metrics,
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

    # /// What it's testing: Active role locks survive lock-file rename, symlink, and lock-directory substitution.
    # /// Why it matters: Mutable lock pathnames must not permit a second owner to delete live role artifacts.
    def test_role_lock_identity_rejects_path_substitution(self) -> None:
        for substitution in ("file", "symlink", "directory"):
            with self.subTest(substitution=substitution), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                allocator = SlotAllocator(root)
                allocator.initialize()
                identity = LeaseIdentity("runner", "ironmain", "trusted")
                compatibility = Compatibility(
                    "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
                )
                first = allocator.acquire_role(
                    SlotId(0), ArtifactRole.STANDARD, compatibility, identity
                )
                (first.root / "active").write_text("preserve")
                lock = allocator.layout.role_lock(
                    SlotId(0), ArtifactRole.STANDARD
                )
                if substitution == "directory":
                    original = lock.parent.with_name("00-original")
                    lock.parent.parent.chmod(0o755)
                    lock.parent.rename(original)
                    lock.parent.mkdir()
                    lock.touch()
                    lock.parent.parent.chmod(0o555)
                else:
                    original = lock.with_name("standard-original.lock")
                    lock.parent.chmod(0o755)
                    lock.rename(original)
                    if substitution == "file":
                        lock.touch()
                    else:
                        outside = root / "outside.lock"
                        outside.touch()
                        lock.symlink_to(outside)
                    lock.parent.chmod(0o555)

                with self.assertRaises(RoleBusy):
                    allocator.acquire_role(
                        SlotId(0),
                        ArtifactRole.STANDARD,
                        Compatibility(
                            "changed", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
                        ),
                        identity,
                    )

                self.assertTrue((first.root / "active").exists())
                first.release(clean=True)

    # /// What it's testing: Replaced active slot and registered-resource locks cannot create duplicate owners.
    # /// Why it matters: Every lock consumer must use stable inode identity rather than mutable path existence.
    def test_slot_and_registered_lock_replacement_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            allocator = SlotAllocator(root / "cache")
            allocator.initialize()
            identity = LeaseIdentity("runner", "ironmain", "trusted")
            first = allocator.acquire(identity)
            self.assertEqual(SlotId(0), first.slot_id)
            slot_lock = allocator.layout.slot_lock(SlotId(0))
            slot_lock.parent.chmod(0o755)
            slot_lock.rename(slot_lock.with_name("slot-original.lock"))
            slot_lock.touch()
            slot_lock.parent.chmod(0o555)

            second = allocator.acquire(identity)

            self.assertEqual(SlotId(1), second.slot_id)
            second.release()
            first.release()

            allowed = root / "targets"
            resource = allowed / "resource"
            resource.mkdir(parents=True)
            registry = ResourceRegistry(
                root / "registry",
                (allowed,),
                monotonic_ns=lambda: 1_000,
                owner_liveness=lambda owner: Liveness.DEAD,
                reference_liveness=lambda path: Liveness.DEAD,
                heartbeat_timeout_ns=100,
            )
            registry.register(
                "stable-lock",
                RegisteredResourceKind.CARGO_TARGET,
                resource,
                ProcessOwner(1234, 5678),
                heartbeat_ns=1,
            )
            held = registry.acquire_resource_lock("stable-lock")
            self.assertIsNotNone(held)
            registered_lock = registry._lock_path("stable-lock")
            registered_lock.rename(registered_lock.with_name("stable-lock-original"))
            registered_lock.touch()
            try:
                self.assertEqual((), registry.cleanup_stale())
                self.assertTrue(resource.exists())
            finally:
                assert held is not None
                held.release()

    # /// What it's testing: Role recycling rejects substituted role-root and mutable-ancestor symlinks.
    # /// Why it matters: In-place invalidation must never follow a runner-controlled path outside the fixed slot.
    def test_role_recycling_preserves_external_targets_after_symlink_substitution(self) -> None:
        for substitution in ("role", "ancestor"):
            with self.subTest(substitution=substitution), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                allocator = SlotAllocator(root / "cache")
                allocator.initialize()
                role = allocator.layout.role_root(SlotId(0), ArtifactRole.STANDARD)
                external = root / "external"
                external.mkdir()
                (external / "important").write_text("preserve")
                if substitution == "role":
                    role.rmdir()
                    role.symlink_to(external, target_is_directory=True)
                else:
                    artifacts = role.parent
                    artifacts.rename(artifacts.with_name("artifacts-original"))
                    artifacts.symlink_to(external, target_is_directory=True)
                    (external / ArtifactRole.STANDARD.value).mkdir()
                    (external / ArtifactRole.STANDARD.value / "important").write_text(
                        "preserve"
                    )

                with self.assertRaises(OSError):
                    allocator.acquire_role(
                        SlotId(0),
                        ArtifactRole.STANDARD,
                        Compatibility(
                            "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
                        ),
                        LeaseIdentity("runner", "ironmain", "trusted"),
                    )

                self.assertTrue((external / "important").exists())
                if substitution == "ancestor":
                    self.assertTrue(
                        (external / ArtifactRole.STANDARD.value / "important").exists()
                    )

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

    # /// What it's testing: Structurally incomplete or extended role state cannot authorize cache reuse.
    # /// Why it matters: The same complete schema must govern semantic reuse and destructive pressure decisions.
    def test_role_reuse_rejects_noncanonical_state(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            compatibility = Compatibility(
                "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
            )
            identity = LeaseIdentity("runner", "ironmain", "trusted")
            first = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, identity
            )
            (first.root / "artifact").write_text("untrusted")
            first.release(clean=True)
            state_path = allocator.layout.role_state(
                SlotId(0), ArtifactRole.STANDARD
            )
            state = json.loads(state_path.read_text())
            state["unexpected"] = "field"
            state_path.write_text(json.dumps(state))

            second = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, identity
            )

            self.assertFalse(second.reused)
            self.assertFalse((second.root / "artifact").exists())
            second.release(clean=True)

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

    # /// What it's testing: Pressure requires complete role state and revalidates it after acquiring both locks.
    # /// Why it matters: Incomplete or concurrently changed metadata must not authorize destructive eviction.
    def test_pressure_rejects_incomplete_and_changed_role_state(self) -> None:
        malformed_states = (
            {"schema": 1, "state": "clean", "last_used_ns": 0},
            {
                "schema": 1,
                "state": "clean",
                "last_used_ns": 0,
                "compatibility": "short",
                "namespace": "runner:ironmain:trusted",
            },
            {
                "schema": 1,
                "state": "clean",
                "last_used_ns": 0,
                "compatibility": "a" * 64,
                "namespace": "unsafe/path",
            },
            {
                "schema": 1,
                "state": "unknown",
                "last_used_ns": 0,
                "compatibility": "a" * 64,
                "namespace": "runner:ironmain:trusted",
            },
            {
                "schema": 1,
                "state": [],
                "last_used_ns": 0,
                "compatibility": "a" * 64,
                "namespace": "runner:ironmain:trusted",
            },
        )
        for index, state in enumerate(malformed_states):
            with self.subTest(index=index), tempfile.TemporaryDirectory() as directory:
                allocator = SlotAllocator(Path(directory))
                allocator.initialize()
                root = allocator.layout.role_root(SlotId(0), ArtifactRole.STANDARD)
                (root / "artifact").write_text("preserve")
                allocator.layout.role_state(SlotId(0), ArtifactRole.STANDARD).write_text(
                    json.dumps(state)
                )
                self.assertEqual([], allocator.evict_under_pressure(lambda: 1.0))
                self.assertTrue((root / "artifact").exists())

        with tempfile.TemporaryDirectory() as directory:
            allocator = SlotAllocator(Path(directory))
            allocator.initialize()
            identity = LeaseIdentity("runner", "ironmain", "trusted")
            compatibility = Compatibility(
                "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
            )
            lease = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, identity
            )
            (lease.root / "artifact").write_text("preserve")
            lease.release(clean=True, last_used_ns=1)
            real_try_fixed_lock = allocator._try_fixed_lock

            # /// Description: Corrupts role state at the simulated post-candidate lock boundary.
            # /// Pre: The allocator is about to acquire one fixed role lock.
            # /// Post: The selected role state becomes incomplete before the real lock is acquired.
            # /// Reason: The regression test must prove locked state is independently revalidated.
            def mutate_before_role_lock(path: Path) -> int | None:
                if path == allocator.layout.role_lock(
                    SlotId(0), ArtifactRole.STANDARD
                ):
                    allocator.layout.role_state(
                        SlotId(0), ArtifactRole.STANDARD
                    ).write_text('{"schema":1,"state":"clean","last_used_ns":1}')
                return real_try_fixed_lock(path)

            with patch.object(
                allocator, "_try_fixed_lock", side_effect=mutate_before_role_lock
            ):
                self.assertEqual([], allocator.evict_under_pressure(lambda: 1.0))
            self.assertTrue((lease.root / "artifact").exists())

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

    # /// What it's testing: Installed-style run commands hold distinct fixed slots and reject broad ambient cgroups as exact telemetry.
    # /// Why it matters: Concurrent callers need real lease isolation and must not turn contaminated aggregate counters into command evidence.
    def test_cli_run_holds_distinct_slots_and_reports_unavailable_outside_invocation_scope(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / "cache"
            SlotAllocator(cache).initialize()
            compatibility = root / "compatibility.json"
            compatibility.write_text(
                json.dumps(
                    {
                        "toolchain": "tool",
                        "lockfile": "lock",
                        "cargo_config": "cargo",
                        "rustflags": "flags",
                        "profile": "profile",
                        "packages": [],
                        "features": [],
                        "nextest_filter": "filter",
                        "script_config": "script",
                    }
                )
            )
            script = Path(slots.__file__)
            commands: list[subprocess.Popen[str]] = []
            outputs: list[Path] = []
            results: list[Path] = []
            for index in range(2):
                output = root / f"child-{index}.json"
                result = root / f"result-{index}.json"
                outputs.append(output)
                results.append(result)
                commands.append(
                    subprocess.Popen(
                        [
                            sys.executable,
                            str(script),
                            "--root",
                            str(cache),
                            "run",
                            "--invocation-id",
                            f"test-{index}",
                            "--repository",
                            "ironmain",
                            "--fork",
                            "trusted",
                            "--role",
                            "standard",
                            "--compatibility",
                            str(compatibility),
                            "--result",
                            str(result),
                            "--",
                            sys.executable,
                            "-c",
                            (
                                "import json,os,time; "
                                f"open({str(output)!r},'w').write(json.dumps(dict(os.environ))); "
                                "time.sleep(0.5)"
                            ),
                        ],
                        text=True,
                    )
                )
            self.assertEqual([0, 0], [command.wait() for command in commands])
            environments = [json.loads(path.read_text()) for path in outputs]
            self.assertNotEqual(
                environments[0]["IRONMAIN_CI_SLOT"],
                environments[1]["IRONMAIN_CI_SLOT"],
            )
            for result in results:
                state = json.loads(result.read_text())
                self.assertEqual("unavailable", state["telemetry"])
                self.assertIsNone(state["physical_write_bytes"])

    # /// What it's testing: The mirror reads Forgejo's host-local repository with an explicit safe upload-pack.
    # /// Why it matters: A private repository cannot be mirrored through unauthenticated HTTP, and Git rejects its forgejo-owned path when root does not explicitly trust that exact source.
    def test_nix_mirror_uses_local_forgejo_source_without_http_auth(self) -> None:
        module = (
            Path(__file__).parent.parent
            / "custom_modules"
            / "ironmain_ci_slots.nix"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'default = "/var/lib/forgejo/repositories/jrestivo/ironmain.git";',
            module,
        )
        self.assertIn("safe.directory=${cfg.mirrorSource}", module)
        self.assertIn(
            "--upload-pack=${lib.escapeShellArg mirrorUploadPack}", module
        )
        self.assertNotIn(
            'default = "http://127.0.0.1:3010/jrestivo/ironmain.git";',
            module,
        )

    # /// What it's testing: The broker and registrar passwordless rules target the host's enabled sudo-rs implementation.
    # /// Why it matters: A generated rule for disabled legacy sudo leaves every deployed invocation blocked on an interactive password.
    def test_nix_broker_uses_enabled_sudo_rs_rules(self) -> None:
        module = (
            Path(__file__).parent.parent
            / "custom_modules"
            / "ironmain_ci_slots.nix"
        ).read_text(encoding="utf-8")
        self.assertIn("security.sudo-rs.extraRules = [", module)
        self.assertNotIn("security.sudo.extraRules = [", module)

    # /// What it's testing: Provisioning repairs mutable-resource and root-only registry ownership after allocator initialization.
    # /// Why it matters: Initialize may create missing directories after tmpfiles, so deployed registration must not inherit root-only defaults or writable registry subdirectories.
    def test_nix_provision_repairs_resource_and_registry_permissions(self) -> None:
        module = (
            Path(__file__).parent.parent
            / "custom_modules"
            / "ironmain_ci_slots.nix"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'chown ${lib.escapeShellArg "${cfg.runnerUser}:${cfg.runnerGroup}"} ${lib.escapeShellArg "${cfg.root}/resources"}',
            module,
        )
        self.assertIn(
            'chmod 0770 ${lib.escapeShellArg "${cfg.root}/resources"}', module
        )
        for registry_path in ("registry/locks", "registry/quarantine", "registry/resources"):
            self.assertIn(
                f'${{lib.escapeShellArg "${{cfg.root}}/{registry_path}"}}', module
            )

    # /// What it's testing: The privileged systemd broker traps cancellation and tears down its exact unit.
    # /// Why it matters: Killing the outer command must not leave expensive work or fixed slot locks running.
    def test_nix_broker_has_explicit_cancellation_teardown(self) -> None:
        module = (
            Path(__file__).parent.parent
            / "custom_modules"
            / "ironmain_ci_slots.nix"
        ).read_text(encoding="utf-8")
        self.assertIn("trap 'cancel 143' TERM", module)
        self.assertIn('systemctl stop "$unit"', module)
        self.assertIn('kill -TERM "$systemd_run_pid"', module)
        self.assertIn(
            'if [ "$observed_description" = "$unit_description" ]; then', module
        )
        self.assertNotIn("exec systemd-run \\", module)

    # /// What it's testing: The privileged broker monitors its exact sudo caller identity and self-cancels after untrappable caller loss.
    # /// Why it matters: SIGKILL cannot be forwarded, so an orphaned root broker must not let expensive work finish clean and become reusable.
    def test_nix_broker_monitors_caller_identity_for_sigkill_recovery(self) -> None:
        module = (
            Path(__file__).parent.parent
            / "custom_modules"
            / "ironmain_ci_slots.nix"
        ).read_text(encoding="utf-8")
        self.assertIn('caller_pid="$PPID"', module)
        self.assertIn('caller_start="$(process_start "$caller_pid")"', module)
        self.assertIn('watch_caller &', module)
        self.assertIn('kill -TERM "$broker_pid"', module)
        self.assertIn('stop_caller_watchdog', module)

    # /// What it's testing: Control-group termination closes child, slot, and role descriptors for immediate recovery.
    # /// Why it matters: The broker's systemd stop must recover bounded capacity even when Python cannot run finally blocks.
    def test_cancelled_command_group_releases_child_slot_and_role(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / "cache"
            allocator = SlotAllocator(cache)
            allocator.initialize()
            compatibility_path = root / "compatibility.json"
            compatibility_state = {
                "toolchain": "tool",
                "lockfile": "lock",
                "cargo_config": "cargo",
                "rustflags": "flags",
                "profile": "profile",
                "packages": [],
                "features": [],
                "nextest_filter": "filter",
                "script_config": "script",
            }
            compatibility_path.write_text(json.dumps(compatibility_state))
            started = root / "started.json"
            command = subprocess.Popen(
                [
                    sys.executable,
                    str(Path(slots.__file__)),
                    "--root",
                    str(cache),
                    "run",
                    "--invocation-id",
                    "cancelled-run",
                    "--repository",
                    "ironmain",
                    "--fork",
                    "trusted",
                    "--role",
                    "standard",
                    "--compatibility",
                    str(compatibility_path),
                    "--",
                    sys.executable,
                    "-c",
                    (
                        "import json,os,time; "
                        f"open({str(started)!r},'w').write(json.dumps("
                        "{'pid':os.getpid(),'slot':os.environ['IRONMAIN_CI_SLOT']})); "
                        "time.sleep(60)"
                    ),
                ],
                start_new_session=True,
            )
            for _ in range(100):
                if started.exists():
                    break
                time.sleep(0.02)
            self.assertTrue(started.exists())
            child = json.loads(started.read_text())
            os.killpg(command.pid, signal.SIGTERM)
            command.wait(timeout=5)
            child_stat = Path("/proc") / str(child["pid"]) / "stat"
            child_state = None
            for _ in range(100):
                try:
                    raw_stat = child_stat.read_text(encoding="utf-8")
                except FileNotFoundError:
                    child_state = None
                    break
                child_state = raw_stat[raw_stat.rfind(")") + 2 :].split()[0]
                if child_state == "Z":
                    break
                time.sleep(0.02)
            self.assertIn(child_state, (None, "Z"))

            identity = LeaseIdentity(
                pwd.getpwuid(os.geteuid()).pw_name, "ironmain", "trusted"
            )
            lease = allocator.acquire(identity)
            self.assertEqual(child["slot"], lease.slot_id.directory_name())
            compatibility = Compatibility(
                "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
            )
            role = allocator.acquire_role(
                lease.slot_id, ArtifactRole.STANDARD, compatibility, identity
            )
            self.assertFalse(role.reused)
            role.release(clean=False)
            lease.release(cancelled=True)

    # /// What it's testing: A failed installed-style run registers and retains its resource as a cleanup candidate.
    # /// Why it matters: Interrupted dirty/staging work must have a production registration producer and released lock.
    def test_cli_failed_run_leaves_registered_cleanup_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / "cache"
            SlotAllocator(cache).initialize()
            compatibility = root / "compatibility.json"
            compatibility.write_text(
                json.dumps(
                    {
                        "toolchain": "tool",
                        "lockfile": "lock",
                        "cargo_config": "cargo",
                        "rustflags": "flags",
                        "profile": "profile",
                        "packages": [],
                        "features": [],
                        "nextest_filter": "filter",
                        "script_config": "script",
                    }
                )
            )
            resource = cache / "resources" / "failed-run"
            resource.mkdir()
            registrar = root / "registrar"
            registrar.write_text(
                "#!/bin/sh\nexec "
                + repr(sys.executable)
                + " "
                + repr(str(Path(slots.__file__)))
                + " --root "
                + repr(str(cache))
                + ' "$@"\n'
            )
            registrar.chmod(0o755)
            result = root / "failed.json"
            completed = subprocess.run(
                [
                    sys.executable,
                    str(Path(slots.__file__)),
                    "--root",
                    str(cache),
                    "run",
                    "--invocation-id",
                    "failed-run",
                    "--repository",
                    "ironmain",
                    "--fork",
                    "trusted",
                    "--role",
                    "standard",
                    "--compatibility",
                    str(compatibility),
                    "--result",
                    str(result),
                    "--register-helper",
                    str(registrar),
                    "--resource-id",
                    "failed-run",
                    "--resource-kind",
                    "staging",
                    "--resource",
                    str(resource),
                    "--",
                    sys.executable,
                    "-c",
                    "raise SystemExit(7)",
                ],
                check=False,
            )
            self.assertEqual(7, completed.returncode)
            self.assertTrue((cache / "registry/resources/failed-run.json").exists())
            registry = ResourceRegistry(cache / "registry", (cache / "resources",))
            lock = registry.acquire_resource_lock("failed-run")
            self.assertIsNotNone(lock)
            if lock is not None:
                lock.release()

    # /// What it's testing: Only an exact uniquely named transient systemd service resolves as an invocation cgroup.
    # /// Why it matters: Broad runner/local slice counters must remain secondary and cannot contaminate command evidence.
    def test_invocation_cgroup_resolution_rejects_broad_scope(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cgroups = root / "cgroup"
            exact = (
                cgroups
                / "ironmain.slice"
                / "ironmain-ci.slice"
                / "ironmain-ci-runner.slice"
                / "ironmain-ci-runner-invocations.slice"
                / "ironmain-ci-invocation-exact-one.service"
            )
            exact.mkdir(parents=True)
            proc_cgroup = root / "self.cgroup"
            proc_cgroup.write_text(
                "0::/ironmain.slice/ironmain-ci.slice/ironmain-ci-runner.slice/"
                "ironmain-ci-runner-invocations.slice/"
                "ironmain-ci-invocation-exact-one.service\n"
            )
            self.assertEqual(
                exact,
                slots._invocation_cgroup_path(
                    "exact-one", proc_cgroup=proc_cgroup, cgroup_root=cgroups
                ),
            )
            proc_cgroup.write_text("0::/ironmain-ci-runner.slice\n")
            self.assertIsNone(
                slots._invocation_cgroup_path(
                    "exact-one", proc_cgroup=proc_cgroup, cgroup_root=cgroups
                )
            )

    # /// What it's testing: The root registration command creates state that a read-only runner can lock.
    # /// Why it matters: The cleanup timer needs a production producer, not only direct test calls into ResourceRegistry.
    def test_cli_registration_produces_runner_consumable_lock(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "cache"
            SlotAllocator(root).initialize()
            resource = root / "resources" / "abandoned"
            resource.mkdir(parents=True)
            for relative in ("registry", "registry/locks", "registry/resources"):
                (root / relative).mkdir(parents=True, exist_ok=True)
            self.assertEqual(
                0,
                slots.main(
                    [
                        "--root",
                        str(root),
                        "register",
                        "--resource-id",
                        "abandoned",
                        "--resource-kind",
                        "staging",
                        "--resource",
                        str(resource),
                        "--owner-pid",
                        str(os.getpid()),
                    ]
                ),
            )
            for relative in ("registry", "registry/locks", "registry/resources"):
                os.chmod(root / relative, 0o555)
            registry = ResourceRegistry(root / "registry", (root / "resources",))
            lock = registry.acquire_resource_lock("abandoned")
            self.assertIsNotNone(lock)
            if lock is not None:
                lock.release()

    # /// What it's testing: Prometheus output reports exact scope counters, slot footprint/reuse, and explicit unavailable telemetry.
    # /// Why it matters: Monitoring must distinguish absent physical I/O from authoritative zero while exposing bounded cache state.
    def test_prometheus_metrics_preserve_scope_availability_and_slot_state(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            allocator = SlotAllocator(root / "cache")
            allocator.initialize()
            identity = LeaseIdentity("runner", "ironmain", "trusted")
            compatibility = Compatibility(
                "tool", "lock", "cargo", "flags", "profile", (), (), "filter", "script"
            )
            role = allocator.acquire_role(
                SlotId(0), ArtifactRole.STANDARD, compatibility, identity
            )
            (role.root / "artifact").write_bytes(b"1234")
            role.release(clean=True)
            runner_scope = root / "runner.scope"
            runner_scope.mkdir()
            (runner_scope / "io.stat").write_text(
                "259:0 rbytes=11 wbytes=22 rios=1 wios=2\n"
            )
            missing_local_scope = root / "local.scope"
            invocation_root = allocator.layout.slot_root(SlotId(0)) / "results"
            invocation = MeteredCommandResult(
                invocation_id="exact-one",
                telemetry=TelemetryAvailability.AVAILABLE,
                physical_read_bytes=33,
                physical_write_bytes=44,
                elapsed_seconds=1.5,
                artifact_bytes=4,
                diagnostic="exact invocation cgroup",
            ).to_state()
            invocation.update(
                {
                    "exit_code": 0,
                    "slot": "00",
                    "role": "standard",
                    "reused": True,
                }
            )
            (invocation_root / "latest-invocation.json").write_text(
                json.dumps(invocation)
            )

            metrics = render_prometheus_metrics(
                allocator.layout,
                {
                    CgroupScope.RUNNER: runner_scope,
                    CgroupScope.LOCAL: missing_local_scope,
                },
            )

            self.assertIn(
                'ironmain_ci_aggregate_scope_io_available{scope="runner"} 1', metrics
            )
            self.assertIn(
                'ironmain_ci_aggregate_scope_physical_write_bytes_total{scope="runner",major_minor="259:0"} 22',
                metrics,
            )
            self.assertIn(
                'ironmain_ci_aggregate_scope_io_available{scope="local"} 0', metrics
            )
            self.assertNotIn(
                'ironmain_ci_aggregate_scope_physical_write_bytes_total{scope="local"',
                metrics,
            )
            self.assertIn(
                'ironmain_ci_invocation_io_available{slot="00",role="standard"} 1',
                metrics,
            )
            self.assertIn(
                'ironmain_ci_invocation_physical_write_bytes{slot="00",role="standard"} 44',
                metrics,
            )
            self.assertIn(
                'ironmain_ci_role_reusable{slot="00",role="standard"} 1',
                metrics,
            )
            self.assertIn(
                'ironmain_ci_role_bytes{slot="00",role="standard"} 4', metrics
            )

    # /// What it's testing: One malformed device line makes the complete cgroup scope unavailable.
    # /// Why it matters: Exporting only a valid subset would undercount writes while falsely claiming exact telemetry.
    def test_prometheus_metrics_reject_partial_scope_io(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            allocator = SlotAllocator(root / "cache")
            allocator.initialize()
            runner_scope = root / "runner.scope"
            local_scope = root / "local.scope"
            runner_scope.mkdir()
            local_scope.mkdir()
            (runner_scope / "io.stat").write_text(
                "259:0 rbytes=11 wbytes=22\n8:0 rbytes=bad wbytes=7\n"
            )
            (local_scope / "io.stat").write_text("8:0 rbytes=1 wbytes=2\n")

            metrics = render_prometheus_metrics(
                allocator.layout,
                {
                    CgroupScope.RUNNER: runner_scope,
                    CgroupScope.LOCAL: local_scope,
                },
            )

            self.assertIn(
                'ironmain_ci_aggregate_scope_io_available{scope="runner"} 0', metrics
            )
            self.assertNotIn(
                'ironmain_ci_aggregate_scope_physical_write_bytes_total{scope="runner"',
                metrics,
            )

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

    # /// What it's testing: Cleanup preserves external and registered data when a resource or ancestor is swapped during liveness checks.
    # /// Why it matters: A runner process must not redirect post-check pathname deletion outside the registered allowed root.
    def test_cleanup_fails_closed_when_resource_path_changes_during_probe(self) -> None:
        for substitution in ("resource", "ancestor"):
            with self.subTest(substitution=substitution), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                allowed = root / "targets"
                parent = allowed / "owned"
                resource = parent / "resource"
                resource.mkdir(parents=True)
                (resource / "registered").write_text("preserve")
                external_parent = root / "external"
                external_resource = external_parent / "resource"
                external_resource.mkdir(parents=True)
                (external_resource / "important").write_text("preserve")

                # /// Description: Substitutes the registered terminal or ancestor during a liveness probe.
                # /// Pre: Registration captured the original resource and allowed-root inode chain.
                # /// Post: The current pathname targets external data while the original remains renamed.
                # /// Reason: The regression test must reproduce the reviewer's cleanup race boundary.
                def swap_path(path: Path) -> Liveness:
                    if substitution == "resource":
                        resource.rename(parent / "resource-original")
                        resource.symlink_to(external_resource, target_is_directory=True)
                    else:
                        parent.rename(allowed / "owned-original")
                        parent.symlink_to(external_parent, target_is_directory=True)
                    return Liveness.DEAD

                registry = ResourceRegistry(
                    root / "registry",
                    (allowed,),
                    monotonic_ns=lambda: 1_000,
                    owner_liveness=lambda owner: Liveness.DEAD,
                    reference_liveness=swap_path,
                    heartbeat_timeout_ns=100,
                )
                registry.register(
                    "resource-swap",
                    RegisteredResourceKind.CARGO_TARGET,
                    resource,
                    ProcessOwner(1234, 5678),
                    heartbeat_ns=1,
                )

                self.assertEqual((), registry.cleanup_stale())
                self.assertTrue((external_resource / "important").exists())
                original = (
                    parent / "resource-original"
                    if substitution == "resource"
                    else allowed / "owned-original" / "resource"
                )
                self.assertTrue((original / "registered").exists())

    # /// What it's testing: Final cleanup refuses a terminal-directory substitution after identity revalidation.
    # /// Why it matters: The final removal operation must name the registered inode rather than an unrelated replacement.
    def test_cleanup_preserves_final_rmdir_boundary_substitution(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            allowed = root / "targets"
            resource = allowed / "resource"
            resource.mkdir(parents=True)
            (resource / "registered").write_text("preserve")
            unrelated = root / "unrelated"
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
                "final-race",
                RegisteredResourceKind.CARGO_TARGET,
                resource,
                ProcessOwner(1234, 5678),
                heartbeat_ns=1,
            )
            real_rename_noreplace = slots._rename_noreplace
            calls = 0

            # /// Description: Substitutes an unrelated directory at the atomic quarantine boundary.
            # /// Pre: Cleanup completed liveness and inode-chain validation for the registered pathname.
            # /// Post: The registered inode is renamed and the unrelated inode occupies its former pathname before capture.
            # /// Reason: The regression reproduces the reviewer's final check-to-remove race.
            def swap_before_quarantine(
                source_directory: int,
                source_name: str,
                destination_directory: int,
                destination_name: str,
            ) -> None:
                nonlocal calls
                calls += 1
                if calls == 1:
                    resource.rename(allowed / "resource-original")
                    unrelated.rename(resource)
                real_rename_noreplace(
                    source_directory,
                    source_name,
                    destination_directory,
                    destination_name,
                )

            with patch.object(
                slots, "_rename_noreplace", side_effect=swap_before_quarantine
            ):
                self.assertEqual((), registry.cleanup_stale())

            self.assertTrue(resource.exists())
            self.assertTrue((allowed / "resource-original" / "registered").exists())

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

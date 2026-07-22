#!/usr/bin/env python3
"""Bounded, role-separated workspace allocation for IronMain CI."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from enum import Enum
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import time
from typing import Callable, Final

SLOT_COUNT: Final = 12
PRESSURE_TRIGGER_PERCENT: Final = 15.0
PRESSURE_TARGET_PERCENT: Final = 20.0
_SAFE_IDENTITY = re.compile(r"\A[A-Za-z0-9](?:[A-Za-z0-9_.-]{0,127})\Z")
_URL_CREDENTIAL = re.compile(r"(?P<scheme>https?://)[^/@\s:]+:[^/@\s]+@", re.IGNORECASE)
_SECRET_ASSIGNMENT = re.compile(r"(?i)\b(token|password|secret)=([^\s]+)")
_BEARER = re.compile(r"(?i)(authorization:\s*bearer\s+)([^\s]+)")


class SlotUnavailable(RuntimeError):
    """Raised when all configured slots have active leases."""


class RoleBusy(RuntimeError):
    """Raised when a role already has an active mutation lease."""


class UnsafeIdentity(ValueError):
    """Raised when an identity cannot safely name shared state."""


class TelemetryAvailability(Enum):
    """Whether authoritative physical I/O counters were available."""

    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"


class Liveness(Enum):
    """A fail-closed result from one independent resource-liveness probe."""

    LIVE = "live"
    DEAD = "dead"
    UNCERTAIN = "uncertain"


class RegisteredResourceKind(Enum):
    """Resource classes the allocator is explicitly allowed to clean."""

    CARGO_TARGET = "cargo-target"
    WORKTREE = "worktree"
    STAGING = "staging"


class ArtifactRole(Enum):
    """The three independently mutable artifact stores in each slot."""

    STANDARD = "standard"
    COVERAGE_BASELINE = "coverage-baseline"
    COVERAGE_CURRENT = "coverage-current"


@dataclass(frozen=True, order=True)
class SlotId:
    """A validated index into the fixed slot set."""

    value: int

    # /// Description: Validates that the slot index belongs to the fixed configured range.
    # /// Pre: The caller supplies an integer index.
    # /// Post: Construction succeeds only for indices zero through eleven.
    # /// Reason: Invalid indices must never create a thirteenth persistent root.
    def __post_init__(self) -> None:
        if (
            isinstance(self.value, bool)
            or not isinstance(self.value, int)
            or not 0 <= self.value < SLOT_COUNT
        ):
            raise ValueError(f"slot index must be between 0 and {SLOT_COUNT - 1}")

    # /// Description: Formats a slot as its stable two-digit directory name.
    # /// Pre: The SlotId has passed construction validation.
    # /// Post: Returns one of 00 through 11.
    # /// Reason: One canonical format prevents identity-derived slot paths.
    def directory_name(self) -> str:
        return f"{self.value:02d}"


@dataclass(frozen=True)
class LeaseIdentity:
    """A trust namespace for a caller leasing a private slot."""

    user: str
    repository: str
    fork: str

    # /// Description: Rejects identity material that could escape or poison a trust namespace.
    # /// Pre: The caller supplies external user, repository, and fork labels.
    # /// Post: Every accepted field is a simple path-independent label without credentials.
    # /// Reason: Shared persistent slots must not bridge users, forks, or unsafe paths.
    def __post_init__(self) -> None:
        for label, value in asdict(self).items():
            if not isinstance(value, str) or not _SAFE_IDENTITY.fullmatch(value):
                raise UnsafeIdentity(f"unsafe {label}: {redact_secrets(str(value))}")

    # /// Description: Returns the canonical non-secret namespace recorded in lease state.
    # /// Pre: The identity has passed construction validation.
    # /// Post: The result is stable and contains no path separator or credential.
    # /// Reason: State consumers need an auditable trust identity without raw boundary input.
    def namespace(self) -> str:
        return f"{self.user}:{self.repository}:{self.fork}"


@dataclass(frozen=True)
class Compatibility:
    """Inputs that determine whether mutable build artifacts can be reused."""

    toolchain: str
    lockfile: str
    cargo_config: str
    rustflags: str
    profile: str
    packages: tuple[str, ...]
    features: tuple[str, ...]
    nextest_filter: str
    script_config: str

    # /// Description: Produces a canonical digest for artifact compatibility inputs.
    # /// Pre: Fields represent already selected build configuration values.
    # /// Post: Equivalent values have one stable SHA-256 digest independent of source commit.
    # /// Reason: Source revisions identify evidence but must not create persistent target paths.
    def digest(self) -> str:
        payload = json.dumps(asdict(self), sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(payload.encode()).hexdigest()


@dataclass(frozen=True)
class MeteredCommandResult:
    """Authoritative command telemetry with explicit unavailable physical I/O."""

    invocation_id: str
    telemetry: TelemetryAvailability
    physical_read_bytes: int | None
    physical_write_bytes: int | None
    elapsed_seconds: float
    artifact_bytes: int
    diagnostic: str

    # /// Description: Validates metering consistency and redacts diagnostic boundary text.
    # /// Pre: The caller supplies counters from one command scope or marks them unavailable.
    # /// Post: Available counters are nonnegative integers; unavailable counters are both null.
    # /// Reason: Missing physical I/O must never become an authoritative zero.
    def __post_init__(self) -> None:
        if not _SAFE_IDENTITY.fullmatch(self.invocation_id):
            raise ValueError("unsafe invocation identity")
        counters = (self.physical_read_bytes, self.physical_write_bytes)
        if self.telemetry is TelemetryAvailability.AVAILABLE:
            if any(
                isinstance(value, bool) or not isinstance(value, int) or value < 0
                for value in counters
            ):
                raise ValueError("available telemetry requires nonnegative counters")
        elif counters != (None, None):
            raise ValueError("unavailable telemetry requires null counters")
        if self.elapsed_seconds < 0 or self.artifact_bytes < 0:
            raise ValueError("elapsed time and artifact footprint must be nonnegative")
        object.__setattr__(self, "diagnostic", redact_secrets(self.diagnostic))

    @classmethod
    # /// Description: Constructs a result for a command whose physical counters are unavailable.
    # /// Pre: Timing and footprint remain observable and nonnegative.
    # /// Post: Both physical counters are null and telemetry is explicitly unavailable.
    # /// Reason: Callers need a convenient truthful alternative to substituting zero.
    def unavailable(
        cls,
        *,
        invocation_id: str,
        elapsed_seconds: float,
        artifact_bytes: int,
        diagnostic: str,
    ) -> "MeteredCommandResult":
        return cls(
            invocation_id=invocation_id,
            telemetry=TelemetryAvailability.UNAVAILABLE,
            physical_read_bytes=None,
            physical_write_bytes=None,
            elapsed_seconds=elapsed_seconds,
            artifact_bytes=artifact_bytes,
            diagnostic=diagnostic,
        )

    # /// Description: Serializes safe command telemetry for atomic allocator state.
    # /// Pre: This result passed construction validation.
    # /// Post: The mapping preserves null unavailable counters and contains a redacted diagnostic.
    # /// Reason: State and log consumers need one truthful credential-safe representation.
    def to_state(self) -> dict[str, object]:
        return {
            "schema": 1,
            "invocation_id": self.invocation_id,
            "telemetry": self.telemetry.value,
            "physical_read_bytes": self.physical_read_bytes,
            "physical_write_bytes": self.physical_write_bytes,
            "elapsed_seconds": self.elapsed_seconds,
            "artifact_bytes": self.artifact_bytes,
            "diagnostic": self.diagnostic,
        }


@dataclass(frozen=True)
class ProcessOwner:
    """A Linux process identity resistant to PID reuse."""

    pid: int
    start_time_ticks: int

    # /// Description: Validates a PID plus procfs start-time identity.
    # /// Pre: Values came from process ownership registration.
    # /// Post: Both fields are positive non-boolean integers.
    # /// Reason: PID alone cannot safely distinguish a live owner from PID reuse.
    def __post_init__(self) -> None:
        for value in (self.pid, self.start_time_ticks):
            if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
                raise ValueError("process owner fields must be positive integers")


@dataclass(frozen=True)
class SlotLayout:
    """Canonical paths beneath the system-owned IronMain cache root."""

    root: Path

    @property
    # /// Description: Enumerates the complete fixed slot identifier set.
    # /// Pre: The layout has a cache root.
    # /// Post: Returns exactly twelve SlotIds in stable order.
    # /// Reason: Callers must not derive slot cardinality from jobs or commits.
    def slot_ids(self) -> tuple[SlotId, ...]:
        return tuple(SlotId(index) for index in range(SLOT_COUNT))

    @property
    # /// Description: Returns the root-managed bare mirror path.
    # /// Pre: The layout has a cache root.
    # /// Post: The path is independent of caller identity and source revision.
    # /// Reason: Repository objects should be stored once and exposed read-only to jobs.
    def mirror_root(self) -> Path:
        return self.root / "mirror.git"

    @property
    # /// Description: Returns the fixed slots container.
    # /// Pre: The layout has a cache root.
    # /// Post: The result is the sole parent of numbered persistent slots.
    # /// Reason: A dedicated container makes cardinality auditable.
    def slots_root(self) -> Path:
        return self.root / "slots"

    # /// Description: Returns one canonical fixed slot root.
    # /// Pre: slot_id is a validated SlotId.
    # /// Post: The path ends in a two-digit configured slot name.
    # /// Reason: No external job or revision may influence persistent paths.
    def slot_root(self, slot_id: SlotId) -> Path:
        return self.slots_root / slot_id.directory_name()

    # /// Description: Returns one stable head or baseline workspace path.
    # /// Pre: name is exactly head or baseline.
    # /// Post: The path stays within the selected fixed slot.
    # /// Reason: Coverage comparison needs separate stable source workspaces.
    def workspace_root(self, slot_id: SlotId, name: str) -> Path:
        if name not in ("head", "baseline"):
            raise ValueError("workspace must be head or baseline")
        return self.slot_root(slot_id) / "workspaces" / name

    # /// Description: Returns one fixed role-separated artifact root.
    # /// Pre: slot_id and role are validated typed values.
    # /// Post: The path is independent of jobs, commits, users, and forks.
    # /// Reason: Fixed rolling roots bound storage while preventing role mutation races.
    def role_root(self, slot_id: SlotId, role: ArtifactRole) -> Path:
        return self.slot_root(slot_id) / "artifacts" / role.value

    # /// Description: Returns the exclusive slot lock path.
    # /// Pre: slot_id is validated.
    # /// Post: The lock path remains outside mutable artifact contents.
    # /// Reason: Slot ownership must survive role recycling.
    def slot_lock(self, slot_id: SlotId) -> Path:
        return self.slot_root(slot_id) / "locks" / "slot.lock"

    # /// Description: Returns the exclusive artifact-role lock path.
    # /// Pre: slot_id and role are validated.
    # /// Post: Each role receives a distinct stable lock.
    # /// Reason: Baseline, current, and standard mutations must never race.
    def role_lock(self, slot_id: SlotId, role: ArtifactRole) -> Path:
        return self.slot_root(slot_id) / "locks" / f"{role.value}.lock"

    # /// Description: Returns the atomic slot state path.
    # /// Pre: slot_id is validated.
    # /// Post: The path remains within the fixed slot state directory.
    # /// Reason: Heartbeat and cancellation state must be discoverable after interruption.
    def slot_state(self, slot_id: SlotId) -> Path:
        return self.slot_root(slot_id) / "state" / "slot.json"

    # /// Description: Returns one atomic artifact-role state path.
    # /// Pre: slot_id and role are validated.
    # /// Post: Each role state is isolated from the other roles.
    # /// Reason: Compatibility and dirty recovery are role-specific.
    def role_state(self, slot_id: SlotId, role: ArtifactRole) -> Path:
        return self.slot_root(slot_id) / "state" / f"{role.value}.json"


# /// Description: Redacts common URL, assignment, and bearer credential forms from text.
# /// Pre: text may contain untrusted diagnostic material.
# /// Post: Recognized secret values are replaced without exposing their original bytes.
# /// Reason: Boundary rejection and logs must never disclose runner credentials.
def redact_secrets(text: str) -> str:
    redacted = _URL_CREDENTIAL.sub(r"\g<scheme>[REDACTED]@", text)
    redacted = _SECRET_ASSIGNMENT.sub(
        lambda match: f"{match.group(1)}=[REDACTED]", redacted
    )
    return _BEARER.sub(r"\1[REDACTED]", redacted)


# /// Description: Writes JSON state through fsync and atomic replacement.
# /// Pre: The parent path is writable by the system allocator.
# /// Post: Readers observe either the previous complete object or the new complete object.
# /// Reason: Cancellation must not leave partially serialized lease or compatibility state.
def _atomic_json(path: Path, value: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{time.time_ns()}.tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        json.dump(value, stream, sort_keys=True, separators=(",", ":"))
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


# /// Description: Opens and attempts to exclusively lock a stable lock file.
# /// Pre: The lock parent belongs to a fixed allocator path.
# /// Post: Returns a held file descriptor or None without blocking.
# /// Reason: Allocation and pressure handling need one shared fail-closed lock primitive.
def _try_lock(path: Path) -> int | None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_RDWR | os.O_CREAT, 0o660)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(descriptor)
        return None
    return descriptor


# /// Description: Unlocks and closes a held lock file descriptor.
# /// Pre: descriptor was returned by _try_lock and has not been released.
# /// Post: Another process may acquire the corresponding exclusive lock.
# /// Reason: Explicit release keeps lease lifetime separate from garbage collection timing.
def _unlock(descriptor: int) -> None:
    fcntl.flock(descriptor, fcntl.LOCK_UN)
    os.close(descriptor)


# /// Description: Removes artifact contents while preserving the fixed rolling role root.
# /// Pre: The caller holds the corresponding exclusive role lock.
# /// Post: The root exists empty and no sibling role is changed.
# /// Reason: Dirty or incompatible state must recycle in place rather than proliferate paths.
def _recycle(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    for child in root.iterdir():
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child)
        else:
            child.unlink()


# /// Description: Reports whether a registered PID/start-time owner still exists.
# /// Pre: owner is a validated ProcessOwner and procfs is mounted at /proc.
# /// Post: Missing PIDs are dead, exact start-time matches are live, and unreadable state is uncertain.
# /// Reason: Cleanup must resist PID reuse and fail closed when process evidence is incomplete.
def _owner_liveness(
    owner: ProcessOwner, proc_root: Path = Path("/proc")
) -> Liveness:
    stat_path = proc_root / str(owner.pid) / "stat"
    try:
        stat = stat_path.read_text(encoding="utf-8")
        fields = stat[stat.rfind(")") + 2 :].split()
        start_time_ticks = int(fields[19])
    except FileNotFoundError:
        return Liveness.DEAD
    except (OSError, ValueError, IndexError):
        return Liveness.UNCERTAIN
    if start_time_ticks == owner.start_time_ticks:
        return Liveness.LIVE
    return Liveness.DEAD


# /// Description: Scans process cwd and fd links for references beneath a registered resource.
# /// Pre: resource is a canonical trusted resource root.
# /// Post: Returns live for a reference, dead after a complete scan, and uncertain on inaccessible evidence.
# /// Reason: An unrelated process reference must prevent deletion even after the registered owner exits.
def _reference_liveness(
    resource: Path, proc_root: Path = Path("/proc")
) -> Liveness:
    try:
        processes = tuple(path for path in proc_root.iterdir() if path.name.isdigit())
    except OSError:
        return Liveness.UNCERTAIN
    for process in processes:
        links = [process / "cwd"]
        try:
            links.extend((process / "fd").iterdir())
        except FileNotFoundError:
            continue
        except (OSError, PermissionError):
            return Liveness.UNCERTAIN
        for link in links:
            try:
                target = Path(os.readlink(link))
            except FileNotFoundError:
                continue
            except (OSError, PermissionError):
                return Liveness.UNCERTAIN
            try:
                target.resolve(strict=False).relative_to(resource)
            except ValueError:
                continue
            return Liveness.LIVE
    return Liveness.DEAD


@dataclass
class ResourceLock:
    """A testable held registration lock used by cleanup and active owners."""

    descriptor: int | None

    # /// Description: Releases one held registered-resource lock.
    # /// Pre: The descriptor is either held or was already released.
    # /// Post: The lock is available to another process and repeated release is harmless.
    # /// Reason: Tests and callers need explicit resource-lock lifetime control.
    def release(self) -> None:
        if self.descriptor is None:
            return
        descriptor, self.descriptor = self.descriptor, None
        _unlock(descriptor)

    # /// Description: Returns a held resource lock to a context-managed caller.
    # /// Pre: The descriptor is held.
    # /// Post: The same lock remains held.
    # /// Reason: Cleanup registration locks should support structured lifetime.
    def __enter__(self) -> "ResourceLock":
        return self

    # /// Description: Releases a context-managed resource lock.
    # /// Pre: Python is exiting the associated with block.
    # /// Post: The resource lock is released.
    # /// Reason: Exceptions must not strand resource ownership.
    def __exit__(
        self, exception_type: object, exception: object, traceback: object
    ) -> None:
        self.release()


class ResourceRegistry:
    """Fail-closed registry and cleanup authority for explicit resource roots."""

    # /// Description: Constructs a cleanup registry with trusted roots and injectable liveness probes.
    # /// Pre: Registry and allowed roots are system-selected rather than caller-derived paths.
    # /// Post: Cleanup can address only strict descendants of canonical allowed roots.
    # /// Reason: Explicit authority boundaries prevent broad target or worktree glob deletion.
    def __init__(
        self,
        registry_root: Path,
        allowed_roots: tuple[Path, ...],
        *,
        monotonic_ns: Callable[[], int] = time.monotonic_ns,
        owner_liveness: Callable[[ProcessOwner], Liveness] = _owner_liveness,
        reference_liveness: Callable[[Path], Liveness] = _reference_liveness,
        heartbeat_timeout_ns: int = 300_000_000_000,
    ) -> None:
        if not allowed_roots:
            raise ValueError("at least one cleanup root is required")
        if heartbeat_timeout_ns <= 0:
            raise ValueError("heartbeat timeout must be positive")
        self.root = registry_root.resolve()
        self.allowed_roots = tuple(path.resolve() for path in allowed_roots)
        self.monotonic_ns = monotonic_ns
        self.owner_liveness = owner_liveness
        self.reference_liveness = reference_liveness
        self.heartbeat_timeout_ns = heartbeat_timeout_ns

    # /// Description: Returns one lock path outside the deletable resource tree.
    # /// Pre: resource_id passed safe identity validation.
    # /// Post: The path is a strict child of the registry lock directory.
    # /// Reason: Cleanup must keep its lock valid while deleting a resource root.
    def _lock_path(self, resource_id: str) -> Path:
        return self.root / "locks" / f"{resource_id}.lock"

    # /// Description: Returns one atomic registration manifest path.
    # /// Pre: resource_id passed safe identity validation.
    # /// Post: The path is a strict child of the registry manifest directory.
    # /// Reason: Cleanup discovers only explicit registrations, never filesystem globs.
    def _manifest_path(self, resource_id: str) -> Path:
        return self.root / "resources" / f"{resource_id}.json"

    # /// Description: Validates and expresses a resource relative to one trusted cleanup root.
    # /// Pre: resource is external path input and allowed roots are canonical.
    # /// Post: Returns an allowed-root index and safe nonempty relative components or raises.
    # /// Reason: Persisted state must not contain traversal, credentials, or arbitrary absolute paths.
    def _relative_resource(self, resource: Path) -> tuple[int, tuple[str, ...]]:
        canonical = resource.resolve(strict=False)
        for index, allowed in enumerate(self.allowed_roots):
            try:
                relative = canonical.relative_to(allowed)
            except ValueError:
                continue
            parts = relative.parts
            if not parts or any(not _SAFE_IDENTITY.fullmatch(part) for part in parts):
                raise ValueError("unsafe or overbroad registered resource path")
            return index, parts
        raise ValueError("registered resource is outside trusted cleanup roots")

    # /// Description: Atomically registers one existing cleanup-owned resource and its live owner evidence.
    # /// Pre: The resource is a real non-symlink directory strictly beneath an allowed root.
    # /// Post: A credential-safe manifest identifies its kind, relative path, owner, and heartbeat.
    # /// Reason: Cleanup may delete only resources that a trusted helper explicitly registered.
    def register(
        self,
        resource_id: str,
        kind: RegisteredResourceKind,
        resource: Path,
        owner: ProcessOwner,
        *,
        heartbeat_ns: int,
    ) -> None:
        if not _SAFE_IDENTITY.fullmatch(resource_id):
            raise ValueError("unsafe resource identity")
        root_index, relative_parts = self._relative_resource(resource)
        if (
            isinstance(heartbeat_ns, bool)
            or not isinstance(heartbeat_ns, int)
            or heartbeat_ns < 0
        ):
            raise ValueError("heartbeat must be a nonnegative monotonic timestamp")
        if not resource.is_dir() or resource.is_symlink():
            raise ValueError("registered resource must be an existing directory")
        _atomic_json(
            self._manifest_path(resource_id),
            {
                "schema": 1,
                "resource_id": resource_id,
                "kind": kind.value,
                "root_index": root_index,
                "relative_parts": list(relative_parts),
                "owner": asdict(owner),
                "heartbeat_ns": heartbeat_ns,
            },
        )

    # /// Description: Acquires one registered-resource lock without blocking.
    # /// Pre: resource_id is a safe registration identity.
    # /// Post: Returns a held lock or None when another process owns it.
    # /// Reason: Active resources and cleanup must share the same exclusion primitive.
    def acquire_resource_lock(self, resource_id: str) -> ResourceLock | None:
        if not _SAFE_IDENTITY.fullmatch(resource_id):
            raise ValueError("unsafe resource identity")
        descriptor = _try_lock(self._lock_path(resource_id))
        return None if descriptor is None else ResourceLock(descriptor)

    # /// Description: Loads and validates one registration without trusting persisted paths or types.
    # /// Pre: manifest_path is discovered only in the registry resources directory.
    # /// Post: Returns typed identity, resource, owner, and heartbeat or None on uncertainty.
    # /// Reason: Corrupt or poisoned registration state must fail closed rather than authorize deletion.
    def _load_registration(
        self, manifest_path: Path
    ) -> tuple[str, Path, ProcessOwner, int] | None:
        try:
            state = json.loads(manifest_path.read_text(encoding="utf-8"))
            resource_id = state["resource_id"]
            if (
                state.get("schema") != 1
                or not isinstance(resource_id, str)
                or not _SAFE_IDENTITY.fullmatch(resource_id)
                or manifest_path != self._manifest_path(resource_id)
            ):
                return None
            RegisteredResourceKind(state["kind"])
            root_index = state["root_index"]
            parts = state["relative_parts"]
            heartbeat_ns = state["heartbeat_ns"]
            if (
                isinstance(root_index, bool)
                or not isinstance(root_index, int)
                or not 0 <= root_index < len(self.allowed_roots)
                or not isinstance(parts, list)
                or not parts
                or any(not isinstance(part, str) or not _SAFE_IDENTITY.fullmatch(part) for part in parts)
                or isinstance(heartbeat_ns, bool)
                or not isinstance(heartbeat_ns, int)
                or heartbeat_ns < 0
            ):
                return None
            owner_state = state["owner"]
            owner = ProcessOwner(owner_state["pid"], owner_state["start_time_ticks"])
            resource = self.allowed_roots[root_index].joinpath(*parts)
            if resource.resolve(strict=False) != resource or resource.is_symlink():
                return None
            self._relative_resource(resource)
            return resource_id, resource, owner, heartbeat_ns
        except (KeyError, OSError, TypeError, ValueError, json.JSONDecodeError):
            return None

    # /// Description: Removes registered stale roots only after lock, heartbeat, owner, cwd, and fd checks are negative.
    # /// Pre: Registrations were written through register and liveness probes are authoritative or return uncertain.
    # /// Post: Returns removed IDs; live, uncertain, locked, malformed, missing, and unregistered paths are preserved.
    # /// Reason: Stale cleanup must recover space without ever guessing that an active resource is abandoned.
    def cleanup_stale(self) -> tuple[str, ...]:
        manifests = self.root / "resources"
        if not manifests.exists():
            return ()
        removed: list[str] = []
        for manifest_path in sorted(manifests.glob("*.json")):
            registration = self._load_registration(manifest_path)
            if registration is None:
                continue
            resource_id, resource, owner, heartbeat_ns = registration
            try:
                lock = self.acquire_resource_lock(resource_id)
            except OSError:
                continue
            if lock is None:
                continue
            with lock:
                now = self.monotonic_ns()
                if now < heartbeat_ns or now - heartbeat_ns <= self.heartbeat_timeout_ns:
                    continue
                if self.owner_liveness(owner) is not Liveness.DEAD:
                    continue
                if self.reference_liveness(resource) is not Liveness.DEAD:
                    continue
                if not resource.is_dir() or resource.is_symlink():
                    continue
                try:
                    shutil.rmtree(resource)
                    manifest_path.unlink()
                except OSError:
                    continue
                removed.append(resource_id)
        return tuple(removed)


@dataclass
class SlotLease:
    """An explicitly released exclusive lease over one private slot."""

    allocator: "SlotAllocator"
    slot_id: SlotId
    identity: LeaseIdentity
    _descriptor: int | None

    # /// Description: Atomically refreshes the active slot heartbeat.
    # /// Pre: This lease still holds its slot lock.
    # /// Post: State identifies the namespace as active with a current monotonic timestamp.
    # /// Reason: Recovery needs durable evidence that a leased slot is still live.
    def heartbeat(self) -> None:
        if self._descriptor is None:
            raise RuntimeError("slot lease is already released")
        _atomic_json(
            self.allocator.layout.slot_state(self.slot_id),
            {
                "schema": 1,
                "state": "active",
                "namespace": self.identity.namespace(),
                "heartbeat_ns": time.monotonic_ns(),
            },
        )

    # /// Description: Marks the slot idle or cancelled and releases its exclusive lock.
    # /// Pre: This lease has not already been released.
    # /// Post: State is complete and the fixed slot can be leased again.
    # /// Reason: Normal completion and cancellation must both recover bounded capacity.
    def release(self, *, cancelled: bool = False) -> None:
        if self._descriptor is None:
            return
        _atomic_json(
            self.allocator.layout.slot_state(self.slot_id),
            {
                "schema": 1,
                "state": "cancelled" if cancelled else "idle",
                "namespace": self.identity.namespace(),
                "heartbeat_ns": time.monotonic_ns(),
            },
        )
        descriptor, self._descriptor = self._descriptor, None
        _unlock(descriptor)

    # /// Description: Releases the slot when leaving a context manager.
    # /// Pre: The lease was entered by a caller using with.
    # /// Post: Exceptions mark cancellation and never strand the lock.
    # /// Reason: Structured lifetime makes interruption recovery the default behavior.
    def __enter__(self) -> "SlotLease":
        return self

    # /// Description: Finalizes context-managed slot ownership.
    # /// Pre: Python is exiting the associated with block.
    # /// Post: The slot lock is released and exception exits are marked cancelled.
    # /// Reason: Callers should not need bespoke cancellation cleanup.
    def __exit__(
        self, exception_type: object, exception: object, traceback: object
    ) -> None:
        self.release(cancelled=exception_type is not None)


@dataclass
class RoleLease:
    """An explicitly released mutation lease over one artifact role."""

    allocator: "SlotAllocator"
    slot_id: SlotId
    role: ArtifactRole
    compatibility: Compatibility
    identity: LeaseIdentity
    root: Path
    reused: bool
    _descriptor: int | None

    # /// Description: Publishes clean or dirty role state and releases role mutation ownership.
    # /// Pre: This lease has not already been released.
    # /// Post: Compatibility, cleanliness, and LRU time are atomically recorded before unlock.
    # /// Reason: Later callers must reuse only complete compatible output and recover dirty output.
    def release(self, *, clean: bool, last_used_ns: int | None = None) -> None:
        if self._descriptor is None:
            return
        _atomic_json(
            self.allocator.layout.role_state(self.slot_id, self.role),
            {
                "schema": 1,
                "state": "clean" if clean else "dirty",
                "compatibility": self.compatibility.digest(),
                "namespace": self.identity.namespace(),
                "last_used_ns": time.monotonic_ns()
                if last_used_ns is None
                else last_used_ns,
            },
        )
        descriptor, self._descriptor = self._descriptor, None
        _unlock(descriptor)

    # /// Description: Returns this role lease to a context-managed caller.
    # /// Pre: The role lock is held.
    # /// Post: The same lease remains active.
    # /// Reason: Role mutation should support structured clean/dirty publication.
    def __enter__(self) -> "RoleLease":
        return self

    # /// Description: Publishes context-managed role completion and unlocks it.
    # /// Pre: Python is exiting the associated with block.
    # /// Post: Success is clean and exception exit is dirty.
    # /// Reason: Partial artifacts must never be mistaken for reusable output.
    def __exit__(
        self, exception_type: object, exception: object, traceback: object
    ) -> None:
        self.release(clean=exception_type is None)


class SlotAllocator:
    """Allocates a fixed set of private slots and rolling artifact roles."""

    # /// Description: Constructs an allocator rooted at one system-selected cache directory.
    # /// Pre: root is a trusted configuration path, not caller-controlled job data.
    # /// Post: The allocator uses one canonical SlotLayout and creates nothing yet.
    # /// Reason: Path authority belongs to system configuration rather than CI identities.
    def __init__(self, root: Path) -> None:
        self.layout = SlotLayout(root.resolve())

    # /// Description: Creates the fixed mirror, workspace, role, lock, and state layout.
    # /// Pre: The configured root is writable by the provisioning authority.
    # /// Post: Exactly twelve slots exist with two stable workspaces and three role roots each.
    # /// Reason: Provisioning once prevents jobs from creating unbounded persistent generations.
    def initialize(self) -> None:
        self.layout.root.mkdir(parents=True, exist_ok=True)
        self.layout.mirror_root.mkdir(parents=True, exist_ok=True)
        (self.layout.mirror_root / "objects").mkdir(exist_ok=True)
        os.chmod(self.layout.mirror_root, 0o550)
        for slot_id in self.layout.slot_ids:
            slot_root = self.layout.slot_root(slot_id)
            (slot_root / "locks").mkdir(parents=True, exist_ok=True)
            (slot_root / "state").mkdir(parents=True, exist_ok=True)
            (slot_root / "results").mkdir(parents=True, exist_ok=True)
            for workspace in ("head", "baseline"):
                info = (
                    self.layout.workspace_root(slot_id, workspace)
                    / ".git"
                    / "objects"
                    / "info"
                )
                info.mkdir(parents=True, exist_ok=True)
                (info / "alternates").write_text(
                    f"{self.layout.mirror_root / 'objects'}\n", encoding="utf-8"
                )
            for role in ArtifactRole:
                self.layout.role_root(slot_id, role).mkdir(parents=True, exist_ok=True)

    # /// Description: Acquires the first available fixed private slot without blocking.
    # /// Pre: initialize has created the layout and identity has passed trust validation.
    # /// Post: Returns one exclusive lease or raises SlotUnavailable without creating a slot.
    # /// Reason: Concurrent jobs need private workspaces under a hard cardinality bound.
    def acquire(self, identity: LeaseIdentity) -> SlotLease:
        for slot_id in self.layout.slot_ids:
            descriptor = _try_lock(self.layout.slot_lock(slot_id))
            if descriptor is not None:
                lease = SlotLease(self, slot_id, identity, descriptor)
                lease.heartbeat()
                return lease
        raise SlotUnavailable(f"all {SLOT_COUNT} IronMain CI slots are leased")

    # /// Description: Acquires one role for exclusive mutation and applies compatibility recovery.
    # /// Pre: initialize has run and the caller supplies typed slot, role, compatibility, and identity values.
    # /// Post: Returns a fixed root reused only when clean, compatible, and in the same trust namespace.
    # /// Reason: Rolling role artifacts reduce writes without allowing concurrent or cross-user poisoned reuse.
    def acquire_role(
        self,
        slot_id: SlotId,
        role: ArtifactRole,
        compatibility: Compatibility,
        identity: LeaseIdentity,
    ) -> RoleLease:
        descriptor = _try_lock(self.layout.role_lock(slot_id, role))
        if descriptor is None:
            raise RoleBusy(
                f"slot {slot_id.directory_name()} role {role.value} is active"
            )
        root = self.layout.role_root(slot_id, role)
        state_path = self.layout.role_state(slot_id, role)
        state: dict[str, object] = {}
        try:
            if state_path.exists():
                state = json.loads(state_path.read_text(encoding="utf-8"))
            reused = (
                state.get("schema") == 1
                and state.get("state") == "clean"
                and state.get("compatibility") == compatibility.digest()
                and state.get("namespace") == identity.namespace()
            )
            if not reused:
                _recycle(root)
            _atomic_json(
                state_path,
                {
                    "schema": 1,
                    "state": "active",
                    "compatibility": compatibility.digest(),
                    "namespace": identity.namespace(),
                    "last_used_ns": time.monotonic_ns(),
                },
            )
            return RoleLease(
                self, slot_id, role, compatibility, identity, root, reused, descriptor
            )
        except Exception:
            _unlock(descriptor)
            raise

    # /// Description: Evicts unlocked least-recently-used role artifacts under filesystem pressure.
    # /// Pre: free_percent reports current free capacity for the configured cache filesystem.
    # /// Post: No eviction starts at 15% or above; below it unlocked LRU roles recycle until 20% or exhaustion.
    # /// Reason: Fixed roots still need pressure bounds without deleting active or healthy caches by age.
    def evict_under_pressure(
        self, free_percent: Callable[[], float] | None = None
    ) -> list[tuple[SlotId, ArtifactRole]]:
        if free_percent is None:
            # /// Description: Reports current free capacity for the allocator filesystem.
            # /// Pre: The allocator root exists on a mounted filesystem.
            # /// Post: Returns free bytes as a percentage of total bytes.
            # /// Reason: Production pressure handling needs the same injectable metric used by tests.
            def free_percent() -> float:
                usage = shutil.disk_usage(self.layout.root)
                return usage.free * 100.0 / usage.total

        current = free_percent()
        if current >= PRESSURE_TRIGGER_PERCENT:
            return []
        candidates: list[tuple[int, SlotId, ArtifactRole]] = []
        for slot_id in self.layout.slot_ids:
            for role in ArtifactRole:
                state_path = self.layout.role_state(slot_id, role)
                if not state_path.exists():
                    continue
                try:
                    state = json.loads(state_path.read_text(encoding="utf-8"))
                    last_used = state["last_used_ns"]
                    if (
                        state.get("schema") != 1
                        or state.get("state")
                        not in ("active", "clean", "dirty", "evicted")
                        or isinstance(last_used, bool)
                        or not isinstance(last_used, int)
                        or last_used < 0
                    ):
                        continue
                except (KeyError, OSError, TypeError, json.JSONDecodeError):
                    continue
                candidates.append((last_used, slot_id, role))
        evicted: list[tuple[SlotId, ArtifactRole]] = []
        for _, slot_id, role in sorted(candidates):
            if current >= PRESSURE_TARGET_PERCENT:
                break
            slot_descriptor = _try_lock(self.layout.slot_lock(slot_id))
            if slot_descriptor is None:
                continue
            descriptor = _try_lock(self.layout.role_lock(slot_id, role))
            if descriptor is None:
                _unlock(slot_descriptor)
                continue
            try:
                _recycle(self.layout.role_root(slot_id, role))
                _atomic_json(
                    self.layout.role_state(slot_id, role),
                    {
                        "schema": 1,
                        "state": "evicted",
                        "compatibility": None,
                        "last_used_ns": time.monotonic_ns(),
                    },
                )
                evicted.append((slot_id, role))
            finally:
                _unlock(descriptor)
                _unlock(slot_descriptor)
            current = free_percent()
        return evicted


# /// Description: Parses the small provisioning command-line interface.
# /// Pre: argv contains trusted system-service arguments or an administrator invocation.
# /// Post: Returns a namespace selecting initialize or describe under one configured root.
# /// Reason: The Nix module needs a stable executable boundary for provisioning and audits.
def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("command", choices=("initialize", "describe"))
    return parser.parse_args(argv)


# /// Description: Provisions or describes the fixed IronMain CI slot layout.
# /// Pre: argv passes _parse_args validation and root is system-selected.
# /// Post: Initialize creates the layout; describe emits its typed fixed cardinality and roles.
# /// Reason: Deployment and closure checks need one machine-readable allocator entrypoint.
def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    allocator = SlotAllocator(args.root)
    if args.command == "initialize":
        allocator.initialize()
    else:
        print(
            json.dumps(
                {
                    "slot_count": SLOT_COUNT,
                    "slots": [
                        slot.directory_name() for slot in allocator.layout.slot_ids
                    ],
                    "roles": [role.value for role in ArtifactRole],
                    "mirror": str(allocator.layout.mirror_root),
                },
                sort_keys=True,
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

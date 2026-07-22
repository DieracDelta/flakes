#!/usr/bin/env python3
"""Bounded, role-separated workspace allocation for IronMain CI."""

from __future__ import annotations

import argparse
import ctypes
from dataclasses import asdict, dataclass
from enum import Enum
import errno
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
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


class UnsafePath(OSError):
    """Raised when a destructive path no longer resolves beneath its trusted anchor."""


class TelemetryAvailability(Enum):
    """Whether authoritative physical I/O counters were available."""

    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"


class CgroupScope(Enum):
    """System-owned terminal execution scopes exported as exact I/O metrics."""

    RUNNER = "runner"
    LOCAL = "local"


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


class ArtifactState(Enum):
    """Complete mutable artifact states eligible for pressure ordering."""

    ACTIVE = "active"
    CLEAN = "clean"
    DIRTY = "dirty"


@dataclass(frozen=True)
class DirectoryIdentity:
    """Stable filesystem identity used to detect path substitution."""

    device: int
    inode: int

    # /// Description: Validates persisted filesystem identity fields.
    # /// Pre: Device and inode came from fstat or untrusted registration JSON.
    # /// Post: Both values are nonnegative non-boolean integers.
    # /// Reason: Mistyped identity state must fail closed before destructive lookup.
    def __post_init__(self) -> None:
        for value in (self.device, self.inode):
            if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                raise ValueError("invalid directory identity")

    # /// Description: Captures a directory's device and inode from an open descriptor.
    # /// Pre: descriptor refers to an opened directory.
    # /// Post: Returns the stable identity needed for later path revalidation.
    # /// Reason: Path strings alone cannot detect rename or symlink substitution races.
    @classmethod
    def from_descriptor(cls, descriptor: int) -> "DirectoryIdentity":
        state = os.fstat(descriptor)
        return cls(state.st_dev, state.st_ino)


@dataclass(frozen=True)
class ArtifactStateRecord:
    """Validated complete role metadata admitted to pressure eviction."""

    state: ArtifactState
    compatibility: str
    namespace: str
    last_used_ns: int


@dataclass(frozen=True)
class ResourceRegistration:
    """Validated cleanup registration with anchored filesystem identities."""

    resource_id: str
    root_index: int
    relative_parts: tuple[str, ...]
    owner: "ProcessOwner"
    heartbeat_ns: int
    root_identity: DirectoryIdentity
    resource_identity: DirectoryIdentity
    lock_identity: DirectoryIdentity


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

    @property
    # /// Description: Returns the root-owned fixed-lock namespace outside runner-owned slots.
    # /// Pre: The layout has a trusted cache root.
    # /// Post: The path is independent of mutable workspaces and artifact trees.
    # /// Reason: Runner jobs must not rename active slot or role lock pathnames.
    def locks_root(self) -> Path:
        return self.root / "locks"

    # /// Description: Returns the exclusive slot lock path.
    # /// Pre: slot_id is validated.
    # /// Post: The lock path remains in the root-owned fixed-lock namespace.
    # /// Reason: Slot ownership must survive role recycling and runner path mutation.
    def slot_lock(self, slot_id: SlotId) -> Path:
        return self.locks_root / slot_id.directory_name() / "slot.lock"

    # /// Description: Returns the exclusive artifact-role lock path.
    # /// Pre: slot_id and role are validated.
    # /// Post: Each role receives a distinct root-owned stable lock.
    # /// Reason: Baseline, current, and standard mutations must never race.
    def role_lock(self, slot_id: SlotId, role: ArtifactRole) -> Path:
        return self.locks_root / slot_id.directory_name() / f"{role.value}.lock"

    # /// Description: Returns immutable expected-inode state for one fixed lock.
    # /// Pre: lock_path is a slot or role lock returned by this layout.
    # /// Post: The identity path is adjacent to but distinct from the lock inode.
    # /// Reason: No-follow opening alone cannot detect rename followed by regular-file replacement.
    def lock_identity(self, lock_path: Path) -> Path:
        return lock_path.with_name(f"{lock_path.name}.identity.json")

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


# /// Description: Provisions one stable lock inode and records its expected identity atomically.
# /// Pre: The caller is the trusted provisioning or registration authority for the parent.
# /// Post: The lock and adjacent identity state exist and refer to the same inode.
# /// Reason: Later callers must distinguish an original lock from a pathname replacement.
def _provision_lock(path: Path, identity_path: Path) -> DirectoryIdentity:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(
        path, os.O_RDONLY | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC, 0o444
    )
    try:
        identity = DirectoryIdentity.from_descriptor(descriptor)
    finally:
        os.close(descriptor)
    _atomic_json(identity_path, {"device": identity.device, "inode": identity.inode})
    os.chmod(path, 0o444, follow_symlinks=False)
    os.chmod(identity_path, 0o444, follow_symlinks=False)
    return identity


# /// Description: Loads an exact persisted stable-lock identity.
# /// Pre: identity_path belongs to a trusted root-owned lock namespace.
# /// Post: Returns a typed identity or None for missing, malformed, or extended state.
# /// Reason: Uncertain lock identity must prevent acquisition rather than create a new lock.
def _load_lock_identity(identity_path: Path) -> DirectoryIdentity | None:
    try:
        value = json.loads(identity_path.read_text(encoding="utf-8"))
        if not isinstance(value, dict) or set(value) != {"device", "inode"}:
            return None
        return DirectoryIdentity(value["device"], value["inode"])
    except (KeyError, OSError, TypeError, ValueError, json.JSONDecodeError):
        return None


# /// Description: Opens and attempts to exclusively lock one pre-provisioned stable inode.
# /// Pre: The lock and trusted identity state were created by _provision_lock.
# /// Post: Returns a held descriptor only when no-follow lookup matches the expected inode and flock succeeds.
# /// Reason: Path replacement must fail closed instead of bypassing an active owner.
def _try_lock(path: Path, expected: DirectoryIdentity | None) -> int | None:
    if expected is None:
        return None
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError:
        return None
    try:
        if DirectoryIdentity.from_descriptor(descriptor) != expected:
            os.close(descriptor)
            return None
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(descriptor)
        return None
    except Exception:
        os.close(descriptor)
        raise
    return descriptor


# /// Description: Unlocks and closes a held lock file descriptor.
# /// Pre: descriptor was returned by _try_lock and has not been released.
# /// Post: Another process may acquire the corresponding exclusive lock.
# /// Reason: Explicit release keeps lease lifetime separate from garbage collection timing.
def _unlock(descriptor: int) -> None:
    fcntl.flock(descriptor, fcntl.LOCK_UN)
    os.close(descriptor)


_DIRECTORY_OPEN_FLAGS: Final = (
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
)
_RENAME_NOREPLACE: Final = 1
_LIBC = ctypes.CDLL(None, use_errno=True)


# /// Description: Atomically renames an entry only when the destination name is absent.
# /// Pre: Both names are safe relative components and descriptors refer to trusted directories on one filesystem.
# /// Post: The source inode moves without replacing an existing destination, or OSError reports no change.
# /// Reason: Quarantine must capture one exact registered inode without deleting a raced replacement.
def _rename_noreplace(
    source_directory: int,
    source_name: str,
    destination_directory: int,
    destination_name: str,
) -> None:
    for name in (source_name, destination_name):
        if not _SAFE_IDENTITY.fullmatch(name):
            raise UnsafePath("unsafe quarantine name")
    renameat2 = getattr(_LIBC, "renameat2", None)
    if renameat2 is None:
        raise OSError(errno.ENOSYS, "renameat2 is unavailable")
    result = renameat2(
        source_directory,
        os.fsencode(source_name),
        destination_directory,
        os.fsencode(destination_name),
        _RENAME_NOREPLACE,
    )
    if result != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))


# /// Description: Opens a directory chain beneath one trusted no-follow anchor.
# /// Pre: Every relative component is a validated simple name and the anchor is system-selected.
# /// Post: Returns held descriptors for anchor through leaf or raises without following symlinks.
# /// Reason: Destructive operations must remain attached to trusted directory inodes, not mutable path strings.
def _open_directory_chain(anchor: Path, parts: tuple[str, ...]) -> list[int]:
    if any(not _SAFE_IDENTITY.fullmatch(part) for part in parts):
        raise UnsafePath("unsafe destructive path component")
    descriptors: list[int] = []
    try:
        descriptors.append(os.open(anchor, _DIRECTORY_OPEN_FLAGS))
        for part in parts:
            descriptors.append(
                os.open(part, _DIRECTORY_OPEN_FLAGS, dir_fd=descriptors[-1])
            )
        return descriptors
    except Exception:
        for descriptor in reversed(descriptors):
            os.close(descriptor)
        raise


# /// Description: Closes a directory chain returned by _open_directory_chain.
# /// Pre: Each descriptor is open and owned by the caller.
# /// Post: Every descriptor is closed in leaf-to-anchor order.
# /// Reason: Anchored deletion should not leak persistent filesystem references.
def _close_directory_chain(descriptors: list[int]) -> None:
    for descriptor in reversed(descriptors):
        os.close(descriptor)


# /// Description: Seals a quarantined stale directory against further runner mutation.
# /// Pre: Cleanup runs as the system authority and descriptor names the captured resource inode.
# /// Post: Root owns the directory when privileged and its mode denies non-owner mutation.
# /// Reason: A process racing with an old directory fd must not substitute nested entries during removal.
def _seal_directory_descriptor(descriptor: int) -> None:
    if os.geteuid() == 0:
        os.fchown(descriptor, 0, 0)
    os.fchmod(descriptor, 0o700)


# /// Description: Removes directory contents using only no-follow descriptor-relative operations.
# /// Pre: descriptor is an exclusively controlled directory beneath a trusted anchor.
# /// Post: Its original inode is empty or an uncertainty raises before traversing a substituted path.
# /// Reason: shutil and Path traversal can follow role or ancestor substitutions outside the cache.
def _clear_directory_descriptor(descriptor: int, *, seal: bool = False) -> None:
    if seal:
        _seal_directory_descriptor(descriptor)
    for entry in tuple(os.scandir(descriptor)):
        try:
            child_descriptor = os.open(
                entry.name, _DIRECTORY_OPEN_FLAGS, dir_fd=descriptor
            )
        except OSError as error:
            if error.errno not in (errno.ENOTDIR, errno.ELOOP):
                raise
            os.unlink(entry.name, dir_fd=descriptor)
            continue
        try:
            child_identity = DirectoryIdentity.from_descriptor(child_descriptor)
            _clear_directory_descriptor(child_descriptor, seal=seal)
            current = os.stat(
                entry.name, dir_fd=descriptor, follow_symlinks=False
            )
            if child_identity != DirectoryIdentity(current.st_dev, current.st_ino):
                raise UnsafePath("directory changed during anchored cleanup")
            os.rmdir(entry.name, dir_fd=descriptor)
        finally:
            os.close(child_descriptor)


# /// Description: Recycles one existing directory beneath a trusted anchor without following substitutions.
# /// Pre: The caller holds the corresponding lock and supplies fixed validated relative components.
# /// Post: The original leaf inode is empty; missing, symlinked, or changed paths raise fail-closed.
# /// Reason: Dirty or incompatible artifacts must recycle in place without escaping fixed slot roots.
def _recycle_beneath(anchor: Path, parts: tuple[str, ...]) -> None:
    descriptors = _open_directory_chain(anchor, parts)
    try:
        _clear_directory_descriptor(descriptors[-1])
    finally:
        _close_directory_chain(descriptors)


# /// Description: Parses one complete role state eligible for pressure eviction.
# /// Pre: value came from untrusted persisted JSON.
# /// Post: Returns typed metadata only for the exact emitted active, clean, or dirty schema.
# /// Reason: Incomplete ownership or compatibility state must not authorize destructive eviction.
def _parse_artifact_state(value: object) -> ArtifactStateRecord | None:
    if not isinstance(value, dict) or set(value) != {
        "schema",
        "state",
        "compatibility",
        "namespace",
        "last_used_ns",
    }:
        return None
    compatibility = value.get("compatibility")
    namespace = value.get("namespace")
    last_used_ns = value.get("last_used_ns")
    try:
        state = ArtifactState(value.get("state"))
    except ValueError:
        return None
    namespace_parts = namespace.split(":") if isinstance(namespace, str) else []
    if (
        value.get("schema") != 1
        or not isinstance(compatibility, str)
        or len(compatibility) != 64
        or any(character not in "0123456789abcdef" for character in compatibility)
        or len(namespace_parts) != 3
        or any(not _SAFE_IDENTITY.fullmatch(part) for part in namespace_parts)
        or isinstance(last_used_ns, bool)
        or not isinstance(last_used_ns, int)
        or last_used_ns < 0
    ):
        return None
    return ArtifactStateRecord(state, compatibility, namespace, last_used_ns)


# /// Description: Produces a stable sortable key for one pressure-eviction candidate.
# /// Pre: candidate contains validated last-use, slot, role, and state values.
# /// Post: Returns integer/string fields that order LRU first without comparing enums.
# /// Reason: Equal timestamps in one slot must not make pressure handling fail open.
def _artifact_candidate_order(
    candidate: tuple[int, SlotId, ArtifactRole, ArtifactStateRecord],
) -> tuple[int, int, str]:
    return candidate[0], candidate[1].value, candidate[2].value


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
        self.quarantine_root = self.root / "quarantine"
        self.quarantine_root.mkdir(parents=True, exist_ok=True)
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

    # /// Description: Returns expected-inode state for one registered-resource lock.
    # /// Pre: resource_id passed safe identity validation.
    # /// Post: The identity path is adjacent to the dynamic lock inode.
    # /// Reason: Cleanup and active owners must reject a replaced registered lock pathname.
    def _lock_identity_path(self, resource_id: str) -> Path:
        return self.root / "locks" / f"{resource_id}.lock.identity.json"

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
        lexical = Path(os.path.abspath(resource))
        for index, allowed in enumerate(self.allowed_roots):
            try:
                relative = lexical.relative_to(allowed)
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
        descriptors = _open_directory_chain(
            self.allowed_roots[root_index], relative_parts
        )
        try:
            root_identity = DirectoryIdentity.from_descriptor(descriptors[0])
            resource_identity = DirectoryIdentity.from_descriptor(descriptors[-1])
        finally:
            _close_directory_chain(descriptors)
        lock_identity = _provision_lock(
            self._lock_path(resource_id), self._lock_identity_path(resource_id)
        )
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
                "root_identity": asdict(root_identity),
                "resource_identity": asdict(resource_identity),
                "lock_identity": asdict(lock_identity),
            },
        )

    # /// Description: Acquires one registered-resource lock without blocking.
    # /// Pre: resource_id is a safe registration identity.
    # /// Post: Returns a held lock or None when another process owns it.
    # /// Reason: Active resources and cleanup must share the same exclusion primitive.
    def acquire_resource_lock(self, resource_id: str) -> ResourceLock | None:
        if not _SAFE_IDENTITY.fullmatch(resource_id):
            raise ValueError("unsafe resource identity")
        registration = self._load_registration(self._manifest_path(resource_id))
        if registration is None:
            return None
        return self._acquire_registered_lock(registration)

    # /// Description: Attempts the exact lock inode recorded by one validated registration.
    # /// Pre: registration came from _load_registration.
    # /// Post: Returns a held lock only when the dynamic pathname still names its original inode.
    # /// Reason: Cleanup must share replacement-safe exclusion with active registered owners.
    def _acquire_registered_lock(
        self, registration: ResourceRegistration
    ) -> ResourceLock | None:
        descriptor = _try_lock(
            self._lock_path(registration.resource_id), registration.lock_identity
        )
        return None if descriptor is None else ResourceLock(descriptor)

    # /// Description: Loads and validates one registration without trusting persisted paths or types.
    # /// Pre: manifest_path is discovered only in the registry resources directory.
    # /// Post: Returns typed identity, resource, owner, and heartbeat or None on uncertainty.
    # /// Reason: Corrupt or poisoned registration state must fail closed rather than authorize deletion.
    def _load_registration(
        self, manifest_path: Path
    ) -> ResourceRegistration | None:
        try:
            state = json.loads(manifest_path.read_text(encoding="utf-8"))
            if not isinstance(state, dict) or set(state) != {
                "schema",
                "resource_id",
                "kind",
                "root_index",
                "relative_parts",
                "owner",
                "heartbeat_ns",
                "root_identity",
                "resource_identity",
                "lock_identity",
            }:
                return None
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
            root_state = state["root_identity"]
            resource_state = state["resource_identity"]
            lock_state = state["lock_identity"]
            return ResourceRegistration(
                resource_id=resource_id,
                root_index=root_index,
                relative_parts=tuple(parts),
                owner=ProcessOwner(
                    owner_state["pid"], owner_state["start_time_ticks"]
                ),
                heartbeat_ns=heartbeat_ns,
                root_identity=DirectoryIdentity(
                    root_state["device"], root_state["inode"]
                ),
                resource_identity=DirectoryIdentity(
                    resource_state["device"], resource_state["inode"]
                ),
                lock_identity=DirectoryIdentity(
                    lock_state["device"], lock_state["inode"]
                ),
            )
        except (KeyError, OSError, TypeError, ValueError, json.JSONDecodeError):
            return None

    # /// Description: Reopens a registration path and compares every component to held descriptors.
    # /// Pre: expected is an open chain from the registered root through resource.
    # /// Post: Returns true only while the current no-follow pathname names the same inode chain.
    # /// Reason: Liveness callbacks may race with ancestor or terminal path substitution.
    def _path_matches_held_chain(
        self, registration: ResourceRegistration, expected: list[int]
    ) -> bool:
        try:
            current = _open_directory_chain(
                self.allowed_roots[registration.root_index],
                registration.relative_parts,
            )
        except OSError:
            return False
        try:
            return len(current) == len(expected) and all(
                DirectoryIdentity.from_descriptor(left)
                == DirectoryIdentity.from_descriptor(right)
                for left, right in zip(current, expected)
            )
        finally:
            _close_directory_chain(current)

    # /// Description: Atomically quarantines and removes only the exact registered resource inode.
    # /// Pre: descriptors hold the unchanged registered chain after every liveness check.
    # /// Post: Returns true only after the registered inode is removed from trusted quarantine; substitutions are restored or preserved.
    # /// Reason: Identity check followed by pathname rmdir leaves a check-to-use race.
    def _quarantine_and_remove(
        self,
        registration: ResourceRegistration,
        descriptors: list[int],
    ) -> bool:
        quarantine_descriptors = _open_directory_chain(self.root, ("quarantine",))
        quarantine_name = "q-" + hashlib.sha256(
            f"{registration.resource_id}:{os.getpid()}:{time.time_ns()}".encode()
        ).hexdigest()
        moved = False
        registered_captured = False
        try:
            _rename_noreplace(
                descriptors[-2],
                registration.relative_parts[-1],
                quarantine_descriptors[-1],
                quarantine_name,
            )
            moved = True
            quarantined = os.open(
                quarantine_name,
                _DIRECTORY_OPEN_FLAGS,
                dir_fd=quarantine_descriptors[-1],
            )
            try:
                registered_captured = (
                    DirectoryIdentity.from_descriptor(quarantined)
                    == registration.resource_identity
                )
                if not registered_captured:
                    try:
                        _rename_noreplace(
                            quarantine_descriptors[-1],
                            quarantine_name,
                            descriptors[-2],
                            registration.relative_parts[-1],
                        )
                        moved = False
                    except OSError:
                        pass
                    return False
                _clear_directory_descriptor(quarantined, seal=True)
            finally:
                os.close(quarantined)
            os.rmdir(quarantine_name, dir_fd=quarantine_descriptors[-1])
            moved = False
            return True
        except OSError:
            return False
        finally:
            if moved and not registered_captured:
                try:
                    _rename_noreplace(
                        quarantine_descriptors[-1],
                        quarantine_name,
                        descriptors[-2],
                        registration.relative_parts[-1],
                    )
                except OSError:
                    pass
            _close_directory_chain(quarantine_descriptors)

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
            try:
                lock = self._acquire_registered_lock(registration)
            except OSError:
                continue
            if lock is None:
                continue
            with lock:
                try:
                    descriptors = _open_directory_chain(
                        self.allowed_roots[registration.root_index],
                        registration.relative_parts,
                    )
                except OSError:
                    continue
                try:
                    if (
                        DirectoryIdentity.from_descriptor(descriptors[0])
                        != registration.root_identity
                        or DirectoryIdentity.from_descriptor(descriptors[-1])
                        != registration.resource_identity
                    ):
                        continue
                    now = self.monotonic_ns()
                    if (
                        now < registration.heartbeat_ns
                        or now - registration.heartbeat_ns
                        <= self.heartbeat_timeout_ns
                    ):
                        continue
                    if self.owner_liveness(registration.owner) is not Liveness.DEAD:
                        continue
                    resource = self.allowed_roots[
                        registration.root_index
                    ].joinpath(*registration.relative_parts)
                    if self.reference_liveness(resource) is not Liveness.DEAD:
                        continue
                    if not self._path_matches_held_chain(registration, descriptors):
                        continue
                    if not self._quarantine_and_remove(registration, descriptors):
                        continue
                    manifest_path.unlink()
                except OSError:
                    continue
                finally:
                    _close_directory_chain(descriptors)
                removed.append(registration.resource_id)
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
        self.layout.locks_root.mkdir(parents=True, exist_ok=True)
        os.chmod(self.layout.locks_root, 0o755)
        for slot_id in self.layout.slot_ids:
            slot_root = self.layout.slot_root(slot_id)
            fixed_lock_root = self.layout.locks_root / slot_id.directory_name()
            fixed_lock_root.mkdir(parents=True, exist_ok=True)
            os.chmod(fixed_lock_root, 0o755)
            fixed_locks = [self.layout.slot_lock(slot_id)] + [
                self.layout.role_lock(slot_id, role) for role in ArtifactRole
            ]
            for lock_path in fixed_locks:
                _provision_lock(
                    lock_path, self.layout.lock_identity(lock_path)
                )
            os.chmod(fixed_lock_root, 0o555)
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
        os.chmod(self.layout.locks_root, 0o555)

    # /// Description: Attempts one fixed lock using its provisioned expected inode.
    # /// Pre: initialize created the lock and adjacent root-owned identity state.
    # /// Post: Returns a held descriptor only for the original stable lock inode.
    # /// Reason: Slot, role, and pressure callers must share replacement-safe acquisition.
    def _try_fixed_lock(self, path: Path) -> int | None:
        return _try_lock(
            path, _load_lock_identity(self.layout.lock_identity(path))
        )

    # /// Description: Acquires the first available fixed private slot without blocking.
    # /// Pre: initialize has created the layout and identity has passed trust validation.
    # /// Post: Returns one exclusive lease or raises SlotUnavailable without creating a slot.
    # /// Reason: Concurrent jobs need private workspaces under a hard cardinality bound.
    def acquire(self, identity: LeaseIdentity) -> SlotLease:
        for slot_id in self.layout.slot_ids:
            descriptor = self._try_fixed_lock(self.layout.slot_lock(slot_id))
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
        descriptor = self._try_fixed_lock(self.layout.role_lock(slot_id, role))
        if descriptor is None:
            raise RoleBusy(
                f"slot {slot_id.directory_name()} role {role.value} is active"
            )
        root = self.layout.role_root(slot_id, role)
        state_path = self.layout.role_state(slot_id, role)
        state: ArtifactStateRecord | None = None
        try:
            if state_path.exists():
                state = _parse_artifact_state(
                    json.loads(state_path.read_text(encoding="utf-8"))
                )
            reused = (
                state is not None
                and state.state is ArtifactState.CLEAN
                and state.compatibility == compatibility.digest()
                and state.namespace == identity.namespace()
            )
            if not reused:
                _recycle_beneath(
                    self.layout.root,
                    (
                        "slots",
                        slot_id.directory_name(),
                        "artifacts",
                        role.value,
                    ),
                )
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
        candidates: list[
            tuple[int, SlotId, ArtifactRole, ArtifactStateRecord]
        ] = []
        for slot_id in self.layout.slot_ids:
            for role in ArtifactRole:
                state_path = self.layout.role_state(slot_id, role)
                if not state_path.exists():
                    continue
                try:
                    state = _parse_artifact_state(
                        json.loads(state_path.read_text(encoding="utf-8"))
                    )
                except (OSError, TypeError, json.JSONDecodeError):
                    continue
                if state is None:
                    continue
                candidates.append((state.last_used_ns, slot_id, role, state))
        evicted: list[tuple[SlotId, ArtifactRole]] = []
        for _, slot_id, role, candidate_state in sorted(
            candidates, key=_artifact_candidate_order
        ):
            if current >= PRESSURE_TARGET_PERCENT:
                break
            slot_descriptor = self._try_fixed_lock(self.layout.slot_lock(slot_id))
            if slot_descriptor is None:
                continue
            descriptor = self._try_fixed_lock(self.layout.role_lock(slot_id, role))
            if descriptor is None:
                _unlock(slot_descriptor)
                continue
            try:
                try:
                    locked_state = _parse_artifact_state(
                        json.loads(
                            self.layout.role_state(slot_id, role).read_text(
                                encoding="utf-8"
                            )
                        )
                    )
                except (OSError, TypeError, json.JSONDecodeError):
                    continue
                if locked_state != candidate_state:
                    continue
                _recycle_beneath(
                    self.layout.root,
                    (
                        "slots",
                        slot_id.directory_name(),
                        "artifacts",
                        role.value,
                    ),
                )
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


# /// Description: Computes regular-file bytes beneath one already anchored directory.
# /// Pre: descriptor names a trusted no-follow directory and the caller accepts a point-in-time gauge.
# /// Post: Returns nonnegative bytes without following symlinks outside the directory tree.
# /// Reason: Slot footprint metrics must not traverse mutable external paths.
def _directory_bytes(descriptor: int) -> int:
    total = 0
    for entry in tuple(os.scandir(descriptor)):
        try:
            child = os.open(
                entry.name, _DIRECTORY_OPEN_FLAGS, dir_fd=descriptor
            )
        except OSError as error:
            if error.errno not in (errno.ENOTDIR, errno.ELOOP):
                continue
            try:
                state = os.stat(
                    entry.name, dir_fd=descriptor, follow_symlinks=False
                )
            except OSError:
                continue
            if stat.S_ISREG(state.st_mode):
                total += state.st_size
            continue
        try:
            total += _directory_bytes(child)
        finally:
            os.close(child)
    return total


# /// Description: Reads exact cgroup-v2 physical I/O counters for one named terminal scope.
# /// Pre: path is the system-selected cgroup directory for that scope.
# /// Post: Returns availability plus validated device counters; missing/malformed data is unavailable with no zero counters.
# /// Reason: Missing physical telemetry must never be represented as authoritative zero.
def _read_scope_io(path: Path) -> tuple[TelemetryAvailability, list[tuple[str, int, int]]]:
    try:
        lines = (path / "io.stat").read_text(encoding="utf-8").splitlines()
    except OSError:
        return TelemetryAvailability.UNAVAILABLE, []
    counters: list[tuple[str, int, int]] = []
    devices: set[str] = set()
    for line in lines:
        fields = line.split()
        if not fields:
            continue
        if not re.fullmatch(r"[0-9]+:[0-9]+", fields[0]) or fields[0] in devices:
            return TelemetryAvailability.UNAVAILABLE, []
        devices.add(fields[0])
        values: dict[str, int] = {}
        for field in fields[1:]:
            try:
                key, raw = field.split("=", 1)
                value = int(raw)
            except ValueError:
                return TelemetryAvailability.UNAVAILABLE, []
            if not key or key in values or value < 0:
                return TelemetryAvailability.UNAVAILABLE, []
            values[key] = value
        if "rbytes" not in values or "wbytes" not in values:
            return TelemetryAvailability.UNAVAILABLE, []
        counters.append((fields[0], values["rbytes"], values["wbytes"]))
    if not counters:
        return TelemetryAvailability.UNAVAILABLE, []
    return TelemetryAvailability.AVAILABLE, counters


# /// Description: Renders exact scope I/O and bounded slot/cache state in Prometheus text format.
# /// Pre: layout is initialized and scope_paths maps typed scopes to their intended cgroups.
# /// Post: Available counters are emitted exactly; unavailable scopes emit only an availability gauge.
# /// Reason: Monitoring and acceptance need truthful physical I/O, footprint, lease, and reuse evidence.
def render_prometheus_metrics(
    layout: SlotLayout, scope_paths: dict[CgroupScope, Path]
) -> str:
    lines = [
        "# HELP ironmain_ci_scope_io_available Whether exact physical cgroup I/O telemetry is available.",
        "# TYPE ironmain_ci_scope_io_available gauge",
        "# HELP ironmain_ci_scope_physical_read_bytes_total Exact physical bytes read by the terminal scope.",
        "# TYPE ironmain_ci_scope_physical_read_bytes_total counter",
        "# HELP ironmain_ci_scope_physical_write_bytes_total Exact physical bytes written by the terminal scope.",
        "# TYPE ironmain_ci_scope_physical_write_bytes_total counter",
        "# HELP ironmain_ci_slot_leased Whether allocator state records the slot as active.",
        "# TYPE ironmain_ci_slot_leased gauge",
        "# HELP ironmain_ci_role_bytes Point-in-time bytes retained by a fixed artifact role.",
        "# TYPE ironmain_ci_role_bytes gauge",
        "# HELP ironmain_ci_role_reusable Whether role state is complete, clean, and reusable.",
        "# TYPE ironmain_ci_role_reusable gauge",
    ]
    for scope in CgroupScope:
        availability, counters = _read_scope_io(scope_paths[scope])
        lines.append(
            f'ironmain_ci_scope_io_available{{scope="{scope.value}"}} '
            f'{1 if availability is TelemetryAvailability.AVAILABLE else 0}'
        )
        for device, reads, writes in counters:
            labels = f'scope="{scope.value}",major_minor="{device}"'
            lines.append(
                f"ironmain_ci_scope_physical_read_bytes_total{{{labels}}} {reads}"
            )
            lines.append(
                f"ironmain_ci_scope_physical_write_bytes_total{{{labels}}} {writes}"
            )
    for slot_id in layout.slot_ids:
        leased = 0
        try:
            slot_state = json.loads(
                layout.slot_state(slot_id).read_text(encoding="utf-8")
            )
            leased = int(
                isinstance(slot_state, dict)
                and slot_state.get("schema") == 1
                and slot_state.get("state") == "active"
            )
        except (OSError, TypeError, json.JSONDecodeError):
            pass
        lines.append(
            f'ironmain_ci_slot_leased{{slot="{slot_id.directory_name()}"}} {leased}'
        )
        for role in ArtifactRole:
            state: ArtifactStateRecord | None = None
            try:
                state = _parse_artifact_state(
                    json.loads(
                        layout.role_state(slot_id, role).read_text(encoding="utf-8")
                    )
                )
            except (OSError, TypeError, json.JSONDecodeError):
                pass
            reusable = int(
                state is not None and state.state is ArtifactState.CLEAN
            )
            descriptors = _open_directory_chain(
                layout.root,
                ("slots", slot_id.directory_name(), "artifacts", role.value),
            )
            try:
                role_bytes = _directory_bytes(descriptors[-1])
            finally:
                _close_directory_chain(descriptors)
            labels = f'slot="{slot_id.directory_name()}",role="{role.value}"'
            lines.append(f"ironmain_ci_role_bytes{{{labels}}} {role_bytes}")
            lines.append(f"ironmain_ci_role_reusable{{{labels}}} {reusable}")
    return "\n".join(lines) + "\n"


# /// Description: Atomically publishes Prometheus text output for node_exporter.
# /// Pre: The parent is the configured textfile collector directory and text is complete.
# /// Post: Readers observe one complete old or new metrics file with mode 0644.
# /// Reason: Collector scrapes must not consume partial telemetry.
def _atomic_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{time.time_ns()}.tmp")
    temporary.write_text(text, encoding="utf-8")
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


# /// Description: Parses typed scope=path command-line values.
# /// Pre: Each value came from trusted system service configuration.
# /// Post: Returns exactly one path for runner and local or raises a parser error.
# /// Reason: Metrics must never silently merge or omit a terminal scope namespace.
def _parse_scope_paths(values: list[str]) -> dict[CgroupScope, Path]:
    paths: dict[CgroupScope, Path] = {}
    for value in values:
        name, separator, raw_path = value.partition("=")
        if not separator or not raw_path:
            raise ValueError("scope must use NAME=PATH")
        scope = CgroupScope(name)
        if scope in paths:
            raise ValueError(f"duplicate scope: {scope.value}")
        paths[scope] = Path(raw_path)
    if set(paths) != set(CgroupScope):
        raise ValueError("runner and local scopes are both required")
    return paths


# /// Description: Parses the small system-owned allocator command-line interface.
# /// Pre: argv contains trusted system-service arguments or an administrator invocation.
# /// Post: Returns a validated command namespace under one configured root.
# /// Reason: Provisioning, pressure, cleanup, and monitoring need one stable executable boundary.
def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument(
        "command", choices=("initialize", "describe", "pressure", "cleanup", "metrics")
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--scope", action="append", default=[])
    return parser.parse_args(argv)


# /// Description: Executes provisioning, audit, pressure, registered cleanup, or metrics publication.
# /// Pre: argv passes _parse_args validation and root is system-selected.
# /// Post: The selected operation completes without broad unregistered cleanup or fabricated telemetry.
# /// Reason: NixOS services require one reviewed authority for the fixed substrate lifecycle.
def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    allocator = SlotAllocator(args.root)
    if args.command == "initialize":
        allocator.initialize()
    elif args.command == "describe":
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
    elif args.command == "pressure":
        allocator.evict_under_pressure()
    elif args.command == "cleanup":
        registry = ResourceRegistry(
            allocator.layout.root / "registry",
            (allocator.layout.root / "resources",),
        )
        registry.cleanup_stale()
    else:
        if args.output is None:
            raise ValueError("metrics requires --output")
        _atomic_text(
            args.output,
            render_prometheus_metrics(
                allocator.layout, _parse_scope_paths(args.scope)
            ),
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

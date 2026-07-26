import argparse
import datetime as dt
import fcntl
import json
import logging
import os
import stat
import subprocess
import tempfile
import time
from contextlib import contextmanager
from pathlib import Path

STATE_VERSION = 1
LOGGER = logging.getLogger("user-io-budget")


def atomic_write(path: Path, content: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, path)
        directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        try:
            temporary_path.unlink()
        except FileNotFoundError:
            pass


def empty_state() -> dict:
    return {"version": STATE_VERSION, "day": None, "last_sample": None, "users": {}}


def valid_state(state: object) -> bool:
    if not isinstance(state, dict) or state.get("version") != STATE_VERSION:
        return False
    if state.get("day") is not None:
        try:
            dt.date.fromisoformat(state["day"])
        except (TypeError, ValueError):
            return False
    if state.get("last_sample") is not None and not isinstance(state["last_sample"], (int, float)):
        return False
    if state.get("boot_id") is not None and not isinstance(state["boot_id"], str):
        return False
    users = state.get("users")
    if not isinstance(users, dict) or (state.get("day") is None and users):
        return False
    required_user_fields = {"name", "used_bytes", "warned", "active"}
    for uid, user in users.items():
        if not isinstance(uid, str) or not uid.isdigit() or not isinstance(user, dict):
            return False
        if not required_user_fields.issubset(user):
            return False
        if not isinstance(user["name"], str) or not user["name"] or not isinstance(user["active"], bool):
            return False
        if not isinstance(user["used_bytes"], int) or user["used_bytes"] < 0:
            return False
        warned = user["warned"]
        if (
            not isinstance(warned, list)
            or len(warned) != len(set(warned))
            or not all(isinstance(value, int) and 0 < value <= 100 for value in warned)
        ):
            return False
        has_inode = "inode" in user
        has_counters = "counters" in user
        if has_inode != has_counters or (has_inode and not isinstance(user["inode"], int)):
            return False
        if user["active"] and not has_inode:
            return False
        counters = user.get("counters", {})
        if not isinstance(counters, dict) or not all(
            isinstance(key, str) and isinstance(value, int) and value >= 0 for key, value in counters.items()
        ):
            return False
    return True


def load_state(path: Path) -> dict:
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return empty_state()
    except (json.JSONDecodeError, OSError) as error:
        LOGGER.error("cannot read persistent budget state %s: %s; failing closed", path, error)
        return {**empty_state(), "state_corrupt": True}
    if not valid_state(state):
        LOGGER.error("persistent budget state %s has an invalid schema; failing closed", path)
        return {**empty_state(), "state_corrupt": True}
    return state


def save_state(path: Path, state: dict) -> None:
    atomic_write(path, json.dumps(state, sort_keys=True, separators=(",", ":")) + "\n")


@contextmanager
def state_lock(state_path: Path):
    lock_path = state_path.with_suffix(state_path.suffix + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_CLOEXEC, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        yield
    finally:
        fcntl.flock(descriptor, fcntl.LOCK_UN)
        os.close(descriptor)


def validate_config(config: object) -> None:
    if not isinstance(config, dict):
        raise ValueError("configuration must be an object")
    devices = config.get("devices")
    users = config.get("users")
    if not isinstance(devices, list) or not devices or not all(isinstance(path, str) and path.startswith("/dev/") for path in devices):
        raise ValueError("devices must be a nonempty list of absolute /dev paths")
    if len(devices) != len(set(devices)):
        raise ValueError("configured devices must be unique")
    if not isinstance(users, list) or not users or not all(isinstance(user, dict) for user in users):
        raise ValueError("users must be a nonempty list")
    names = [user.get("name") for user in users]
    uids = [user.get("uid") for user in users]
    if not all(isinstance(name, str) and name for name in names) or len(names) != len(set(names)):
        raise ValueError("configured user names must be nonempty and unique")
    if not all(isinstance(uid, int) and uid > 0 for uid in uids) or len(uids) != len(set(uids)):
        raise ValueError("configured UIDs must be positive and unique")
    for key in ("daily_bytes", "burst_bps", "exhausted_bps"):
        if not isinstance(config.get(key), int) or config[key] <= 0:
            raise ValueError(f"{key} must be a positive integer")
    if config["exhausted_bps"] >= config["burst_bps"]:
        raise ValueError("exhausted_bps must be lower than burst_bps")
    for user in users:
        if not isinstance(user.get("daily_bytes"), int) or user["daily_bytes"] <= 0:
            raise ValueError("every user daily_bytes value must be positive")
    percentages = config.get("warning_percentages")
    if not isinstance(percentages, list) or not all(isinstance(value, int) and 0 < value < 100 for value in percentages):
        raise ValueError("warning percentages must be integers between 1 and 99")
    if len(percentages) != len(set(percentages)):
        raise ValueError("warning percentages must be unique")


def resolve_devices(device_paths: list[str]) -> list[dict]:
    devices = []
    seen_major_minor = set()
    for device_path in device_paths:
        info = os.stat(device_path)
        if not stat.S_ISBLK(info.st_mode):
            raise ValueError(f"configured device is not a block device: {device_path}")
        major_minor = f"{os.major(info.st_rdev)}:{os.minor(info.st_rdev)}"
        sys_device = Path("/sys/dev/block") / major_minor
        try:
            resolved = sys_device.resolve(strict=True)
        except FileNotFoundError as error:
            raise ValueError(f"configured block device is missing from sysfs: {device_path}") from error
        if "/virtual/" in str(resolved) or (resolved / "partition").exists():
            raise ValueError(f"configured device must be a whole physical device: {device_path}")
        if major_minor in seen_major_minor:
            raise ValueError(f"configured device aliases resolve to the same block device: {device_path}")
        seen_major_minor.add(major_minor)
        devices.append({"path": device_path, "major_minor": major_minor})
    return devices


def read_cgroup(cgroup_path: Path, devices: list[dict]) -> tuple[int, dict[str, int]] | None:
    try:
        directory_fd = os.open(cgroup_path, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    except FileNotFoundError:
        return None
    try:
        inode = os.fstat(directory_fd).st_ino
        stat_fd = os.open("io.stat", os.O_RDONLY | os.O_CLOEXEC, dir_fd=directory_fd)
        with os.fdopen(stat_fd, "r", encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except FileNotFoundError:
        return None
    finally:
        os.close(directory_fd)

    wanted = {device["major_minor"] for device in devices}
    counters = {major_minor: 0 for major_minor in wanted}
    for line in lines:
        fields = line.split()
        if not fields or fields[0] not in wanted:
            continue
        for field in fields[1:]:
            key, separator, value = field.partition("=")
            if key == "wbytes" and separator:
                try:
                    counters[fields[0]] = int(value)
                except ValueError:
                    pass
                break
    return inode, counters


def counter_delta(previous: dict, inode: int, counters: dict[str, int]) -> int:
    if not previous:
        return 0
    previous_counters = previous.get("counters", {})
    if previous.get("inode") != inode:
        return sum(counters.values())

    delta = 0
    for major_minor, current in counters.items():
        old = int(previous_counters.get(major_minor, 0))
        delta += current - old if current >= old else current
    return delta


def read_boot_id(path: Path = Path("/proc/sys/kernel/random/boot_id")) -> str:
    return path.read_text(encoding="utf-8").strip()


def parse_io_max(path: Path) -> dict[str, dict[str, str]]:
    result = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return result
    for line in lines:
        fields = line.split()
        if not fields:
            continue
        values = {}
        for field in fields[1:]:
            key, separator, value = field.partition("=")
            if separator:
                values[key] = value
        result[fields[0]] = values
    return result


def set_systemd_write_limit(unit: str, devices: list[dict], bytes_per_second: int) -> None:
    properties = [
        f"IOWriteBandwidthMax={device['path']} {bytes_per_second}" for device in devices
    ]
    process = subprocess.run(
        ["systemctl", "set-property", "--runtime", "--no-ask-password", unit, *properties],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip() or f"exit {process.returncode}"
        raise RuntimeError(f"systemd rejected the write limit for {unit}: {detail}")


def apply_write_limit(cgroup_path: Path, devices: list[dict], bytes_per_second: int) -> bool:
    io_max = cgroup_path / "io.max"
    existing = parse_io_max(io_max)
    desired = str(bytes_per_second)
    if all(existing.get(device["major_minor"], {}).get("wbps") == desired for device in devices):
        return False

    set_systemd_write_limit(cgroup_path.name, devices, bytes_per_second)
    verified = parse_io_max(io_max)
    errors = []
    for device in devices:
        major_minor = device["major_minor"]
        if verified.get(major_minor, {}).get("wbps") != desired:
            errors.append(f"{major_minor}: effective wbps is not {desired}")
    if errors:
        raise RuntimeError("could not verify the systemd write limit: " + "; ".join(errors))
    return True


def notify_user_terminals(uid: int, message: str, pts_root: Path = Path("/dev/pts")) -> int:
    safe_message = "".join(character for character in message if character >= " " or character == "\t")
    payload = f"\r\n*** DISK WRITE BUDGET: {safe_message} ***\r\n".encode("utf-8", errors="replace")
    notified = 0
    try:
        terminals = list(pts_root.iterdir())
    except OSError:
        return 0
    for terminal in terminals:
        if not terminal.name.isdigit():
            continue
        try:
            descriptor = os.open(
                terminal,
                os.O_WRONLY | os.O_NONBLOCK | os.O_NOCTTY | os.O_NOFOLLOW | os.O_CLOEXEC,
            )
            try:
                info = os.fstat(descriptor)
                if info.st_uid != uid or not stat.S_ISCHR(info.st_mode):
                    continue
                os.write(descriptor, payload)
            finally:
                os.close(descriptor)
            notified += 1
        except OSError:
            continue
    return notified


def escape_label(value: object) -> str:
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def render_metrics(results: list[dict], timestamp: float) -> str:
    lines = [
        "# HELP user_io_budget_used_bytes Physical write bytes charged to the current daily user budget.",
        "# TYPE user_io_budget_used_bytes gauge",
        "# HELP user_io_budget_limit_bytes Configured daily physical write budget in bytes.",
        "# TYPE user_io_budget_limit_bytes gauge",
        "# HELP user_io_budget_usage_ratio Fraction of the daily physical write budget consumed.",
        "# TYPE user_io_budget_usage_ratio gauge",
        "# HELP user_io_budget_throttled Whether the exhausted-budget write throttle is active.",
        "# TYPE user_io_budget_throttled gauge",
        "# HELP user_io_budget_cgroup_active Whether the configured user cgroup currently exists.",
        "# TYPE user_io_budget_cgroup_active gauge",
        "# HELP user_io_budget_last_success_timestamp_seconds Last successful budget-controller sample.",
        "# TYPE user_io_budget_last_success_timestamp_seconds gauge",
    ]
    for result in results:
        labels = f'user="{escape_label(result["name"])}",uid="{result["uid"]}"'
        limit = result["limit"]
        used = result["used"]
        ratio = used / limit if limit else 0.0
        lines.extend(
            [
                f"user_io_budget_used_bytes{{{labels}}} {used}",
                f"user_io_budget_limit_bytes{{{labels}}} {limit}",
                f"user_io_budget_usage_ratio{{{labels}}} {ratio:.9f}",
                f"user_io_budget_throttled{{{labels}}} {1 if result['throttled'] else 0}",
                f"user_io_budget_cgroup_active{{{labels}}} {1 if result['active'] else 0}",
                f"user_io_budget_last_success_timestamp_seconds{{{labels}}} {timestamp:.3f}",
            ]
        )
    return "\n".join(lines) + "\n"


def run_once(config: dict, state_path: Path, metrics_path: Path, cgroup_root: Path, now: float | None = None) -> list[dict]:
    validate_config(config)
    now = time.time() if now is None else now
    local_day = dt.datetime.fromtimestamp(now).astimezone().date().isoformat()
    devices = resolve_devices(config["devices"])
    state = load_state(state_path)
    state_corrupt = bool(state.pop("state_corrupt", False))
    boot_id = read_boot_id()
    previous_boot_id = state.get("boot_id")
    boot_changed = previous_boot_id is not None and previous_boot_id != boot_id
    previous_day = state.get("day")
    clock_rollback = previous_day is not None and local_day < previous_day
    if clock_rollback:
        LOGGER.error("local date moved backward from %s to %s; retaining the existing budget day", previous_day, local_day)
        local_day = previous_day
    new_day = previous_day not in (None, local_day)
    results = []
    pending_notifications = []

    if state_corrupt:
        LOGGER.critical("persistent accounting state is corrupt; all configured users remain throttled until local midnight")
    elif new_day:
        LOGGER.info("starting write budget day %s; restoring normal burst ceilings", local_day)

    configured_uids = set()
    for user in config["users"]:
        name = user["name"]
        uid = int(user["uid"])
        configured_uids.add(str(uid))
        limit = int(user.get("daily_bytes") or config["daily_bytes"])
        user_state = state["users"].get(str(uid), {})
        cgroup_path = cgroup_root / "user.slice" / f"user-{uid}.slice"
        sample = read_cgroup(cgroup_path, devices)
        active = sample is not None
        delta = 0

        if sample is not None:
            inode, counters = sample
            delta = sum(counters.values()) if boot_changed and user_state else counter_delta(user_state, inode, counters)
            if state_corrupt:
                used = limit
                warned = list(config.get("warning_percentages", []))
            elif new_day:
                # Charge the complete interval that crossed midnight to the new
                # day. This may overcount by at most one polling interval, but
                # never grants unmeasured writes to a fresh budget.
                used = delta
                warned = []
            elif previous_day is None:
                used = 0
                warned = []
            else:
                used = int(user_state.get("used_bytes", 0)) + delta
                warned = [int(value) for value in user_state.get("warned", [])]
            user_state.update({"inode": inode, "counters": counters})
        elif state_corrupt:
            used = limit
            warned = list(config.get("warning_percentages", []))
        else:
            used = 0 if new_day or previous_day is None else int(user_state.get("used_bytes", 0))
            warned = [] if new_day or previous_day is None else [int(value) for value in user_state.get("warned", [])]
            if boot_changed:
                # Keep the reboot transition pending for this user. If its
                # slice appears later, the new counter is charged from zero.
                user_state.pop("inode", None)
                user_state.pop("counters", None)

        for percentage in sorted({int(value) for value in config.get("warning_percentages", [])}):
            if used * 100 >= limit * percentage and percentage not in warned:
                pending_notifications.append(
                    (
                        logging.WARNING,
                        f"user {name} ({uid}) reached {percentage}% of the daily write budget: "
                        f"{used / 1_000_000_000:.3f} GB / {limit / 1_000_000_000:.3f} GB",
                        uid,
                        f"{name} used {used / 1_000_000_000:.1f} / {limit / 1_000_000_000:.1f} GB ({percentage}%).",
                    )
                )
                warned.append(percentage)

        throttled = used >= limit
        if throttled and 100 not in warned:
            pending_notifications.append(
                (
                    logging.ERROR,
                    f"user {name} ({uid}) exhausted the daily write budget: "
                    f"{used / 1_000_000_000:.3f} GB / {limit / 1_000_000_000:.3f} GB; "
                    "throttling until local midnight",
                    uid,
                    f"{name} exhausted the {limit / 1_000_000_000:.1f} GB daily budget; writes are limited to {int(config['exhausted_bps']) / 1_000:.0f} KB/s per NVMe until local midnight.",
                )
            )
            warned.append(100)

        rate = int(config["exhausted_bps"] if throttled else config["burst_bps"])
        if active and apply_write_limit(cgroup_path, devices, rate):
            LOGGER.info("set user %s (%d) write ceiling to %d bytes/s per device", name, uid, rate)

        user_state.update(
            {
                "name": name,
                "used_bytes": used,
                "warned": sorted(set(warned)),
                "active": active,
            }
        )
        state["users"][str(uid)] = user_state
        results.append(
            {
                "name": name,
                "uid": uid,
                "used": used,
                "limit": limit,
                "active": active,
                "throttled": throttled,
                "delta": delta,
            }
        )

    state["users"] = {uid: value for uid, value in state["users"].items() if uid in configured_uids}
    state.update({"version": STATE_VERSION, "boot_id": boot_id, "day": local_day, "last_sample": now})
    save_state(state_path, state)
    for level, journal_message, uid, terminal_message in pending_notifications:
        LOGGER.log(level, journal_message)
        if config.get("terminal_notifications", True):
            notify_user_terminals(uid, terminal_message)
    atomic_write(metrics_path, render_metrics(results, now), mode=0o644)
    return results


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Enforce daily cgroup-v2 physical write budgets")
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--state", required=True, type=Path)
    parser.add_argument("--metrics", required=True, type=Path)
    parser.add_argument("--cgroup-root", default=Path("/sys/fs/cgroup"), type=Path)
    return parser.parse_args()


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    args = parse_args()
    try:
        config = json.loads(args.config.read_text(encoding="utf-8"))
        with state_lock(args.state):
            run_once(config, args.state, args.metrics, args.cgroup_root)
    except Exception:
        LOGGER.exception("budget controller failed")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env bash
# Create a consistent, offline Forgejo 15 backup immediately before the v16
# switch. This intentionally leaves Forgejo and its runners stopped so the
# operator can switch generations without any post-backup writes.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "run as root (for example: sudo $0)" >&2
  exit 1
fi

state_dir=/var/lib/forgejo
backup_root=${FORGEJO_PREUPGRADE_BACKUP_ROOT:-/var/backup/forgejo-preupgrade}
timestamp=$(date --utc +%Y%m%dT%H%M%SZ)
destination="$backup_root/$timestamp"
config="$state_dir/custom/conf/app.ini"
restart_on_failure=1

forgejo_bin=$(
  systemctl show forgejo.service --property=ExecStart --value \
    | sed -n 's/.*path=\([^ ;]*\).*/\1/p'
)
if [[ ! -x $forgejo_bin ]]; then
  echo "could not resolve the running Forgejo executable" >&2
  exit 1
fi
running_version=$($forgejo_bin --version)
if [[ $running_version != *"forgejo version 15.0.6 "* ]]; then
  echo "refusing backup from unexpected version: $running_version" >&2
  exit 1
fi
if ! systemctl is-active --quiet forgejo.service; then
  echo "forgejo.service must be running so its queues can be flushed" >&2
  exit 1
fi

recover_on_error() {
  local status=$?
  if [[ $status -ne 0 && $restart_on_failure -eq 1 ]]; then
    echo "backup failed; restarting the v15 services" >&2
    systemctl start forgejo.service
    systemctl start forgejo-mcp.service
    systemctl start 'gitea-runner-desktop*.service'
  fi
  exit "$status"
}
trap recover_on_error EXIT

mkdir -p "$destination"
chmod 0700 "$backup_root" "$destination"
printf '%s\n' "$running_version" >"$destination/forgejo-version.txt"

# Queue payload formats are not guaranteed to be compatible across majors.
runuser -u forgejo -- env \
  HOME="$state_dir" USER=forgejo FORGEJO_WORK_DIR="$state_dir" \
  FORGEJO_CUSTOM="$state_dir/custom" \
  "$forgejo_bin" manager flush-queues \
    --work-path "$state_dir" --config "$config" --timeout 10m

systemctl stop 'gitea-runner-desktop*.service'
systemctl stop forgejo-mcp.service
systemctl stop forgejo.service
if systemctl is-active --quiet forgejo.service; then
  echo "forgejo.service did not stop" >&2
  exit 1
fi

# Forgejo's upgrade guide requires a database-native backup in addition to its
# application files. Keeping the service stopped makes these artifacts a
# consistent point-in-time pair.
runuser -u postgres -- pg_dump --format=custom forgejo \
  >"$destination/forgejo.pgcustom"

tar --acls --xattrs --numeric-owner --one-file-system \
  --exclude='./dump' \
  --directory="$state_dir" \
  --use-compress-program='zstd -T0 -10' \
  --create --file="$destination/forgejo-state.tar.zst" .

pg_restore --list "$destination/forgejo.pgcustom" >/dev/null
tar --use-compress-program='zstd -d -T0' \
  --list --file="$destination/forgejo-state.tar.zst" >/dev/null
(
  cd "$destination"
  sha256sum forgejo.pgcustom forgejo-state.tar.zst >SHA256SUMS
)

restart_on_failure=0
trap - EXIT
printf 'Forgejo pre-upgrade backup created at %s\n' "$destination"
printf 'Forgejo, Forgejo MCP, and both runners remain stopped.\n'
printf 'Next: switch the Forgejo 16 generation, then start and verify forgejo.service.\n'

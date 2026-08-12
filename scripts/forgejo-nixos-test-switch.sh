#!/usr/bin/env bash

if [[ $# -gt 1 ]]; then
  printf 'usage: %s [REPOSITORY_ROOT]\n' "${0##*/}" >&2
  exit 64
fi

# repo_root and runner_work_root schema: absolute filesystem path strings.
repo_root=$(realpath -e -- "${1:-.}")
runner_work_root=/var/cache/forgejo-actions/work

if [[ "$repo_root" != "$runner_work_root/"* || ! -f "$repo_root/flake.nix" ]]; then
  printf 'refusing to test a flake outside %s: %s\n' "$runner_work_root" "$repo_root" >&2
  exit 64
fi

# Prevent concurrent jobs from changing the running system beneath each other.
exec {lock_fd}>/run/lock/forgejo-nixos-test-switch.lock
if ! flock --nonblock "$lock_fd"; then
  printf 'another NixOS test switch is already running\n' >&2
  exit 75
fi

# original_system schema: canonical Nix store path behind /run/current-system.
original_system=$(readlink -e /run/current-system)

restore_original_system() {
  local test_status=$?
  local restored_system
  local rollback_status

  trap - EXIT HUP INT TERM
  set +e

  printf 'restoring %s\n' "$original_system"
  "$original_system/bin/switch-to-configuration" test
  rollback_status=$?
  restored_system=$(readlink -e /run/current-system)

  if [[ $rollback_status -ne 0 || "$restored_system" != "$original_system" ]]; then
    printf 'failed to restore %s; /run/current-system is %s\n' \
      "$original_system" "${restored_system:-unresolved}" >&2
    exit 125
  fi

  exit "$test_status"
}

# Preserve the test status after restoring the exact pre-test system. The trap
# also attempts restoration when nixos-rebuild fails or the job is interrupted.
trap restore_original_system EXIT HUP INT TERM

nixos-rebuild test \
  --flake "${repo_root}#desktop" \
  --no-write-lock-file \
  --print-build-logs

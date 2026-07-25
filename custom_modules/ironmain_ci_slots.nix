# /// Description: Defines the opt-in system-owned IronMain CI slot and mirror substrate.
# /// Pre: The host supplies an existing runner user/group before enabling the module.
# /// Post: Configuration exposes exactly twelve fixed slots and one root-managed read-only mirror.
# /// Reason: CI jobs need bounded private workspaces and reusable role-separated artifacts.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom_modules.ironmain_ci_slots;
  # /// Description: Formats one validated configured slot index as a stable directory name.
  # /// Pre: The index comes from the fixed zero-through-eleven range below.
  # /// Post: Returns a two-digit name from 00 through 11.
  # /// Reason: Persistent paths must not depend on external job or commit identities.
  slotName = index: lib.fixedWidthNumber 2 index;
  slotNames = map slotName (lib.range 0 11);
  roles = [
    "standard"
    "coverage-baseline"
    "coverage-current"
  ];
  layout = {
    schema = 1;
    slot_count = builtins.length slotNames;
    slots = slotNames;
    inherit roles;
    mirror = "${cfg.root}/mirror.git";
    mirror_lock = "${cfg.root}/mirror.lock";
    test_projects = "${cfg.root}/test-projects/current";
    test_projects_pin = "${cfg.root}/test-projects/current.sha";
    locks = "${cfg.root}/locks";
    registry = "${cfg.root}/registry";
    quarantine = "${cfg.root}/registry/quarantine";
    resources = "${cfg.root}/resources";
    metrics = cfg.metricsOutput;
    scopes = {
      runner_aggregate = "ironmain-ci-runner.slice";
      local_aggregate = "ironmain-ci-local.slice";
      runner_invocations = "ironmain-ci-runner-invocations.slice";
      local_invocations = "ironmain-ci-local-invocations.slice";
    };
  };
  helper = pkgs.writeShellApplication {
    name = "ironmain-ci-slots";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../scripts/ironmain_ci_slots.py} "$@"
    '';
  };
  rootRegistrar = pkgs.writeShellApplication {
    name = "ironmain-ci-root-registrar";
    runtimeInputs = [ helper ];
    text = ''
      case "''${1:-}" in
        register|unregister) ;;
        *)
          echo "root registrar permits only register or unregister" >&2
          exit 64
          ;;
      esac
      exec ironmain-ci-slots --root ${lib.escapeShellArg cfg.root} "$@"
    '';
  };
  registrationClient = pkgs.writeShellApplication {
    name = "ironmain-ci-register";
    runtimeInputs = [ pkgs.sudo ];
    text = ''
      exec /run/wrappers/bin/sudo ${rootRegistrar}/bin/ironmain-ci-root-registrar "$@"
    '';
  };
  invocationBroker = pkgs.writeShellApplication {
    name = "ironmain-ci-invocation-broker";
    runtimeInputs = [
      helper
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      if [ "$#" -lt 2 ]; then
        echo "usage: ironmain-ci-invocation-broker INVOCATION RUN-OPTIONS... -- COMMAND..." >&2
        exit 64
      fi
      invocation="$1"
      shift
      if [[ ! "$invocation" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$ ]]; then
        echo "unsafe invocation identity" >&2
        exit 64
      fi
      supplementary_properties=()
      if [ "''${SUDO_USER:-}" = ${lib.escapeShellArg cfg.runnerUser} ]; then
        slice=ironmain-ci-runner-invocations.slice
      elif [ "''${SUDO_USER:-}" = ${lib.escapeShellArg cfg.localUser} ]; then
        slice=ironmain-ci-local-invocations.slice
        supplementary_properties=(--property=SupplementaryGroups=${lib.escapeShellArg cfg.runnerGroup})
      else
        echo "invocation broker requires an approved sudo caller" >&2
        exit 77
      fi
      if [[ ! "''${SUDO_UID:-}" =~ ^[0-9]+$ ]] || [[ ! "''${SUDO_GID:-}" =~ ^[0-9]+$ ]]; then
        echo "invocation broker requires sudo UID/GID identity" >&2
        exit 77
      fi
      unit="ironmain-ci-invocation-$invocation.service"
      unit_description="IronMain invocation $invocation broker $BASHPID"
      systemd_run_pid=
      cancellation_status=0
      broker_pid=$BASHPID
      caller_pid="$PPID"
      caller_watchdog_pid=

      # /// Description: Reads one process's PID-reuse-resistant start-time identity.
      # /// Pre: pid names a procfs process visible to the privileged broker.
      # /// Post: Prints Linux start time or returns nonzero when the process is absent or malformed.
      # /// Reason: Caller-loss recovery must not mistake a reused PID for the original sudo process.
      process_start() {
        local raw tail
        local -a fields
        [ -r "/proc/$1/stat" ] || return 1
        raw="$(<"/proc/$1/stat")"
        tail="''${raw##*) }"
        read -r -a fields <<< "$tail"
        [ -n "''${fields[19]:-}" ] || return 1
        printf '%s\n' "''${fields[19]}"
      }
      caller_start="$(process_start "$caller_pid")"
      if [ -z "$caller_start" ]; then
        echo "invocation broker cannot verify its sudo caller" >&2
        exit 77
      fi

      # /// Description: Stops and reaps the caller-identity watchdog when broker work ends.
      # /// Pre: caller_watchdog_pid is empty or identifies this broker's background watchdog.
      # /// Post: No watchdog remains able to signal the broker after completion.
      # /// Reason: Normal completion and explicit cancellation must not leak monitor processes.
      stop_caller_watchdog() {
        if [ -n "$caller_watchdog_pid" ]; then
          kill -TERM "$caller_watchdog_pid" 2>/dev/null || true
          wait "$caller_watchdog_pid" 2>/dev/null || true
          caller_watchdog_pid=
        fi
      }

      # /// Description: Cancels this broker when its exact sudo caller identity disappears.
      # /// Pre: caller_pid and caller_start identify the process that launched this broker.
      # /// Post: Signals only this broker after caller death or PID reuse; otherwise keeps waiting.
      # /// Reason: SIGKILL cannot be forwarded by sudo, so orphaned expensive work needs bounded recovery.
      watch_caller() {
        while [ "$(process_start "$caller_pid" 2>/dev/null || true)" = "$caller_start" ]; do
          sleep 0.1
        done
        kill -TERM "$broker_pid" 2>/dev/null || true
      }

      # /// Description: Stops the exact transient invocation when its waiting caller is cancelled.
      # /// Pre: A trusted invocation unit may be starting or active under systemd_run_pid.
      # /// Post: No child remains in the unit; the broker returns the conventional signal status.
      # /// Reason: Killing systemd-run alone does not stop the system-owned transient service.
      cancel() {
        cancellation_status="$1"
        stop_caller_watchdog
        if [ -z "$systemd_run_pid" ]; then
          return
        fi
        trap : HUP INT TERM
        kill -TERM "$systemd_run_pid" 2>/dev/null || true
        wait "$systemd_run_pid" 2>/dev/null || true
        observed_description="$(systemctl show "$unit" --property=Description --value 2>/dev/null || true)"
        if [ "$observed_description" = "$unit_description" ]; then
          systemctl stop "$unit" >/dev/null 2>&1 || true
        fi
        exit "$cancellation_status"
      }
      trap 'cancel 129' HUP
      trap 'cancel 130' INT
      trap 'cancel 143' TERM
      watch_caller &
      caller_watchdog_pid=$!

      systemd-run \
        --quiet \
        --wait \
        --pipe \
        --collect \
        --service-type=exec \
        --unit="$unit" \
        --description="$unit_description" \
        --slice="$slice" \
        --uid="$SUDO_UID" \
        --gid="$SUDO_GID" \
        --property="WorkingDirectory=$PWD" \
        --property=KillMode=control-group \
        --property=TimeoutStopSec=10s \
        "''${supplementary_properties[@]}" \
        --setenv="IRONMAIN_CI_BROKER_INVOCATION=$invocation" \
        --setenv="IRONMAIN_TEST_PROJECTS_ROOT=${cfg.root}/test-projects/current" \
        ${helper}/bin/ironmain-ci-slots \
        --root ${lib.escapeShellArg cfg.root} \
        run \
        --invocation-id "$invocation" \
        --register-helper ${registrationClient}/bin/ironmain-ci-register \
        "$@" &
      systemd_run_pid=$!
      if [ "$cancellation_status" -ne 0 ]; then
        cancel "$cancellation_status"
      fi
      set +e
      wait "$systemd_run_pid"
      status=$?
      set -e
      stop_caller_watchdog
      trap - HUP INT TERM
      exit "$status"
    '';
  };
  invocationCommand = pkgs.writeShellApplication {
    name = "ironmain-ci-run";
    runtimeInputs = [ pkgs.sudo ];
    text = ''
      exec /run/wrappers/bin/sudo ${invocationBroker}/bin/ironmain-ci-invocation-broker "$@"
    '';
  };
  mirrorUploadPack = "${pkgs.git}/bin/git -c safe.directory=${cfg.mirrorSource} upload-pack";
  mirrorUpdate = pkgs.writeShellApplication {
    name = "ironmain-ci-mirror-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.util-linux
    ];
    text = ''
      exec 9>${lib.escapeShellArg "${cfg.root}/mirror.lock"}
      flock --exclusive 9
      if [ ! -f ${lib.escapeShellArg "${cfg.root}/mirror.git/HEAD"} ]; then
        git init --bare ${lib.escapeShellArg "${cfg.root}/mirror.git"}
      fi
      if git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} remote get-url origin >/dev/null 2>&1; then
        git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} remote set-url origin ${lib.escapeShellArg cfg.mirrorSource}
      else
        git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} remote add origin ${lib.escapeShellArg cfg.mirrorSource}
      fi
      fetch_status=1
      for attempt in $(seq 1 5); do
        if git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} \
          fetch \
          --upload-pack=${lib.escapeShellArg mirrorUploadPack} \
          --prune \
          origin \
          '+refs/*:refs/*'; then
          fetch_status=0
          break
        fi
        echo "mirror refresh attempt $attempt failed; retrying" >&2
        sleep 1
      done
      if [ "$fetch_status" -ne 0 ]; then
        echo "mirror refresh remained incomplete after 5 attempts" >&2
        exit "$fetch_status"
      fi
      chown -R root:${lib.escapeShellArg cfg.runnerGroup} ${lib.escapeShellArg "${cfg.root}/mirror.git"}
      chmod -R g-w,o-rwx ${lib.escapeShellArg "${cfg.root}/mirror.git"}
      chmod 0750 ${lib.escapeShellArg "${cfg.root}/mirror.git"}
    '';
  };
  testProjectsUploadPack = "${pkgs.git}/bin/git -c safe.directory=${cfg.testProjectsSource} upload-pack";
  testProjectsUpdate = pkgs.writeShellApplication {
    name = "ironmain-ci-test-projects-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.gnutar
      pkgs.util-linux
    ];
    text = ''
      root=${lib.escapeShellArg "${cfg.root}/test-projects"}
      snapshots="$root/snapshots"
      mirror="$root/mirror.git"
      lock=${lib.escapeShellArg "${cfg.root}/test-projects.lock"}
      install -d -m 0750 -o root -g ${lib.escapeShellArg cfg.runnerGroup} "$root" "$snapshots" "$mirror"
      exec 9>"$lock"
      flock --exclusive 9

      if [ ! -f "$mirror/HEAD" ]; then
        git init --bare "$mirror"
      fi
      if git --git-dir="$mirror" remote get-url origin >/dev/null 2>&1; then
        git --git-dir="$mirror" remote set-url origin ${lib.escapeShellArg cfg.testProjectsSource}
      else
        git --git-dir="$mirror" remote add origin ${lib.escapeShellArg cfg.testProjectsSource}
      fi
      git --git-dir="$mirror" fetch \
        --upload-pack=${lib.escapeShellArg testProjectsUploadPack} \
        --depth=1 \
        origin \
        ${lib.escapeShellArg "+${cfg.testProjectsRef}:refs/remotes/origin/ironmain-test-projects"}
      commit="$(git --git-dir="$mirror" rev-parse refs/remotes/origin/ironmain-test-projects)"
      if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
        echo "test-projects publisher resolved an invalid commit" >&2
        exit 1
      fi

      snapshot="$snapshots/$commit"
      if [ ! -d "$snapshot" ]; then
        staging="$snapshots/.staging-$commit-$$"
        trap 'rm -rf -- "$staging"' EXIT
        mkdir "$staging"
        git --git-dir="$mirror" archive "$commit" | tar -x -C "$staging"
        sentinel="$staging/do_use/zopeneditor-sample/ASM/ASAM1.asm"
        if [ ! -f "$sentinel" ]; then
          echo "test-projects snapshot lacks the required sentinel" >&2
          exit 1
        fi
        chown -R root:${lib.escapeShellArg cfg.runnerGroup} "$staging"
        chmod -R u=rwX,g=rX,o= "$staging"
        chmod -R a-w "$staging"
        mv "$staging" "$snapshot"
        trap - EXIT
      fi

      expected="snapshots/$commit"
      if [ "$(readlink "$root/current" 2>/dev/null || true)" != "$expected" ]; then
        next_link="$root/.current-$commit-$$"
        ln -s "snapshots/$commit" "$next_link"
        mv -Tf "$next_link" "$root/current"
      fi
      if [ "$(cat "$root/current.sha" 2>/dev/null || true)" != "$commit" ]; then
        pin="$root/.current.sha-$commit-$$"
        printf '%s\n' "$commit" > "$pin"
        chown root:${lib.escapeShellArg cfg.runnerGroup} "$pin"
        chmod 0440 "$pin"
        mv -f "$pin" "$root/current.sha"
      fi

      find "$snapshots" -mindepth 1 -maxdepth 1 -type d -mtime +21 \
        ! -path "$snapshot" -exec rm -rf -- {} +
    '';
  };
  metricsCollector = pkgs.writeShellApplication {
    name = "ironmain-ci-metrics-collector";
    runtimeInputs = [
      pkgs.findutils
      helper
    ];
    text = ''
      runner_scope="$(${pkgs.findutils}/bin/find /sys/fs/cgroup -type d -name ironmain-ci-runner.slice -print -quit 2>/dev/null || true)"
      local_scope="$(${pkgs.findutils}/bin/find /sys/fs/cgroup/user.slice -type d -name ironmain-ci-local.slice -print -quit 2>/dev/null || true)"
      if [ -z "$runner_scope" ]; then
        runner_scope=/sys/fs/cgroup/ironmain-ci-runner.slice
      fi
      if [ -z "$local_scope" ]; then
        local_scope=/sys/fs/cgroup/user.slice/ironmain-ci-local.slice
      fi
      ironmain-ci-slots \
        --root ${lib.escapeShellArg cfg.root} \
        metrics \
        --output ${lib.escapeShellArg cfg.metricsOutput} \
        --scope "runner=$runner_scope" \
        --scope "local=$local_scope"
    '';
  };
  provision = pkgs.writeShellApplication {
    name = "ironmain-ci-slots-provision";
    runtimeInputs = [
      pkgs.coreutils
      helper
    ];
    text = ''
      ironmain-ci-slots --root ${lib.escapeShellArg cfg.root} initialize
      chown -R ${lib.escapeShellArg "${cfg.runnerUser}:${cfg.runnerGroup}"} ${lib.escapeShellArg "${cfg.root}/slots"}
      chown ${lib.escapeShellArg "${cfg.runnerUser}:${cfg.runnerGroup}"} ${lib.escapeShellArg "${cfg.root}/resources"}
      chown -R root:root ${lib.escapeShellArg "${cfg.root}/locks"} ${lib.escapeShellArg "${cfg.root}/registry"}
      chmod 0555 \
        ${lib.escapeShellArg "${cfg.root}/locks"} \
        ${lib.escapeShellArg "${cfg.root}/registry"} \
        ${lib.escapeShellArg "${cfg.root}/registry/locks"} \
        ${lib.escapeShellArg "${cfg.root}/registry/quarantine"} \
        ${lib.escapeShellArg "${cfg.root}/registry/resources"}
      chmod 0770 ${lib.escapeShellArg "${cfg.root}/resources"}
      chmod 0750 ${lib.escapeShellArg "${cfg.root}/mirror.git"}
      chown root:${lib.escapeShellArg cfg.runnerGroup} \
        ${lib.escapeShellArg "${cfg.root}/test-projects"} \
        ${lib.escapeShellArg "${cfg.root}/test-projects/snapshots"} \
        ${lib.escapeShellArg "${cfg.root}/test-projects/mirror.git"}
      chmod 0750 \
        ${lib.escapeShellArg "${cfg.root}/test-projects"} \
        ${lib.escapeShellArg "${cfg.root}/test-projects/snapshots"} \
        ${lib.escapeShellArg "${cfg.root}/test-projects/mirror.git"}
      touch ${lib.escapeShellArg "${cfg.root}/mirror.lock"} ${lib.escapeShellArg "${cfg.root}/test-projects.lock"}
      chown root:root ${lib.escapeShellArg "${cfg.root}/mirror.lock"} ${lib.escapeShellArg "${cfg.root}/test-projects.lock"}
      chmod 0644 ${lib.escapeShellArg "${cfg.root}/mirror.lock"} ${lib.escapeShellArg "${cfg.root}/test-projects.lock"}
    '';
  };
in
{
  options.custom_modules.ironmain_ci_slots = {
    enable = lib.mkEnableOption "bounded IronMain CI slots";

    root = lib.mkOption {
      type = lib.types.path;
      default = "/var/cache/forgejo-actions/ironmain";
      description = "System-owned root containing the mirror and twelve fixed slots.";
    };

    runnerUser = lib.mkOption {
      type = lib.types.str;
      default = "gitea-runner";
      description = "User allowed to mutate private slot workspaces and artifacts.";
    };

    runnerGroup = lib.mkOption {
      type = lib.types.str;
      default = "gitea-runner";
      description = "Group granted read-only traversal of the root-managed mirror.";
    };

    localUser = lib.mkOption {
      type = lib.types.str;
      default = "jrestivo";
      description = "Local orchestrator allowed to use the same fixed slots in an isolated trust namespace.";
    };

    mirrorSource = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/forgejo/repositories/jrestivo/ironmain.git";
      description = "Host-local Forgejo repository used by root to refresh the job-read-only mirror without credentials.";
    };

    testProjectsSource = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/forgejo/repositories/jrestivo/ironmain_test_projects.git";
      description = "Host-local Forgejo repository published as a pinned read-only shared corpus.";
    };

    testProjectsRef = lib.mkOption {
      type = lib.types.str;
      default = "refs/heads/master";
      description = "Exact remote ref resolved by the weekly shared-corpus publisher.";
    };

    metricsOutput = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/node_exporter/textfile_collector/ironmain_ci.prom";
      description = "Prometheus textfile containing exact scope and bounded slot metrics.";
    };

    slotCount = lib.mkOption {
      type = lib.types.int;
      default = 12;
      readOnly = true;
      description = "Fixed IronMain CI slot cardinality; intentionally not configurable per job.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = helper;
      readOnly = true;
      description = "Typed slot allocator and audit command.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.slotCount == 12 && builtins.length slotNames == 12;
          message = "IronMain CI requires exactly twelve persistent slots";
        }
        {
          assertion = builtins.length roles == 3;
          message = "IronMain CI requires standard, coverage-baseline, and coverage-current roles";
        }
      ];
      system.build.ironmainCiSlotsLayout = pkgs.writeText "ironmain-ci-slots-layout.json" (
        builtins.toJSON layout
      );
    }

    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        helper
        invocationCommand
      ];

      users.users.${cfg.localUser}.extraGroups = [ cfg.runnerGroup ];
      security.sudo-rs.extraRules = [
        {
          users = [
            cfg.runnerUser
            cfg.localUser
          ];
          commands = [
            {
              command = "${invocationBroker}/bin/ironmain-ci-invocation-broker";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${rootRegistrar}/bin/ironmain-ci-root-registrar";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.root} 0750 root ${cfg.runnerGroup} -"
        "d ${cfg.root}/mirror.git 0750 root ${cfg.runnerGroup} -"
        "f+ ${cfg.root}/mirror.lock 0644 root root -"
        "d ${cfg.root}/test-projects 0750 root ${cfg.runnerGroup} -"
        "d ${cfg.root}/test-projects/snapshots 0750 root ${cfg.runnerGroup} -"
        "d ${cfg.root}/test-projects/mirror.git 0750 root ${cfg.runnerGroup} -"
        "f+ ${cfg.root}/test-projects.lock 0644 root root -"
        "d ${cfg.root}/locks 0555 root root -"
        "d ${cfg.root}/registry 0555 root root -"
        "d ${cfg.root}/registry/locks 0555 root root -"
        "d ${cfg.root}/registry/quarantine 0555 root root -"
        "d ${cfg.root}/registry/resources 0555 root root -"
        "d ${cfg.root}/resources 0770 ${cfg.runnerUser} ${cfg.runnerGroup} -"
        "d ${cfg.root}/slots 0770 ${cfg.runnerUser} ${cfg.runnerGroup} -"
      ];

      systemd.services.ironmain-ci-slots-provision = {
        description = "Provision bounded IronMain CI slots";
        wantedBy = [ "multi-user.target" ];
        before = [
          "gitea-runner-desktop.service"
          "gitea-runner-desktop\\x2ddocker.service"
          "ironmain-ci-mirror-update.service"
          "ironmain-ci-test-projects-update.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
          Group = "root";
          UMask = "0007";
          ExecStart = "${provision}/bin/ironmain-ci-slots-provision";
        };
      };

      systemd.services.ironmain-ci-mirror-update = {
        description = "Refresh the root-managed IronMain Git mirror";
        wantedBy = [ "multi-user.target" ];
        before = [
          "gitea-runner-desktop.service"
          "gitea-runner-desktop\\x2ddocker.service"
        ];
        after = [
          "forgejo.service"
          "ironmain-ci-slots-provision.service"
        ];
        requires = [
          "forgejo.service"
          "ironmain-ci-slots-provision.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          UMask = "0027";
          ExecStart = "${mirrorUpdate}/bin/ironmain-ci-mirror-update";
          ReadWritePaths = [ cfg.root ];
        };
      };

      systemd.timers.ironmain-ci-mirror-update = {
        description = "Refresh the IronMain Git mirror every minute";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2m";
          OnUnitActiveSec = "1m";
          AccuracySec = "10s";
          Persistent = true;
        };
      };

      systemd.services.ironmain-ci-test-projects-update = {
        description = "Publish one pinned read-only IronMain test-projects snapshot";
        wantedBy = [ "multi-user.target" ];
        before = [
          "gitea-runner-desktop.service"
          "gitea-runner-desktop\\x2ddocker.service"
        ];
        after = [
          "forgejo.service"
          "ironmain-ci-slots-provision.service"
        ];
        requires = [
          "forgejo.service"
          "ironmain-ci-slots-provision.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          UMask = "0027";
          ExecStart = "${testProjectsUpdate}/bin/ironmain-ci-test-projects-update";
          ReadWritePaths = [ cfg.root ];
        };
      };

      systemd.timers.ironmain-ci-test-projects-update = {
        description = "Advance the pinned IronMain test-projects snapshot weekly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };

      systemd.services.ironmain-ci-pressure = {
        description = "Evict unlocked IronMain role artifacts under disk pressure";
        after = [ "ironmain-ci-slots-provision.service" ];
        requires = [ "ironmain-ci-slots-provision.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          ExecStart = "${helper}/bin/ironmain-ci-slots --root ${cfg.root} pressure";
          ReadWritePaths = [ cfg.root ];
        };
      };

      systemd.timers.ironmain-ci-pressure = {
        description = "Check IronMain cache pressure every five minutes";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "5m";
          AccuracySec = "30s";
          Persistent = true;
        };
      };

      systemd.services.ironmain-ci-cleanup = {
        description = "Clean only proven-stale registered IronMain resources";
        after = [ "ironmain-ci-slots-provision.service" ];
        requires = [ "ironmain-ci-slots-provision.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          ExecStart = "${helper}/bin/ironmain-ci-slots --root ${cfg.root} cleanup";
          ReadWritePaths = [ cfg.root ];
        };
      };

      systemd.timers.ironmain-ci-cleanup = {
        description = "Clean registered stale IronMain resources hourly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
      };

      systemd.services.ironmain-ci-metrics = {
        description = "Export exact IronMain scope I/O and slot metrics";
        after = [ "ironmain-ci-slots-provision.service" ];
        requires = [ "ironmain-ci-slots-provision.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          ExecStart = "${metricsCollector}/bin/ironmain-ci-metrics-collector";
          ReadWritePaths = [ (builtins.dirOf cfg.metricsOutput) ];
        };
      };

      systemd.timers.ironmain-ci-metrics = {
        description = "Collect IronMain exact I/O and slot metrics every minute";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* *:*:00";
          AccuracySec = "10s";
          Persistent = true;
        };
      };

      systemd.slices = {
        ironmain-ci-runner.sliceConfig = {
          IOAccounting = true;
          CPUAccounting = true;
          MemoryAccounting = true;
        };
        ironmain-ci-local.sliceConfig = {
          IOAccounting = true;
          CPUAccounting = true;
          MemoryAccounting = true;
        };
        ironmain-ci-runner-invocations.sliceConfig = {
          IOAccounting = true;
          CPUAccounting = true;
          MemoryAccounting = true;
        };
        ironmain-ci-local-invocations.sliceConfig = {
          IOAccounting = true;
          CPUAccounting = true;
          MemoryAccounting = true;
        };
      };
      systemd.services.gitea-runner-desktop = {
        after = [
          "ironmain-ci-mirror-update.service"
          "ironmain-ci-test-projects-update.service"
        ];
        requires = [
          "ironmain-ci-mirror-update.service"
          "ironmain-ci-test-projects-update.service"
        ];
        serviceConfig.Slice = "ironmain-ci-runner.slice";
      };
      systemd.services."gitea-runner-desktop\\x2ddocker" = {
        after = [
          "ironmain-ci-mirror-update.service"
          "ironmain-ci-test-projects-update.service"
        ];
        requires = [
          "ironmain-ci-mirror-update.service"
          "ironmain-ci-test-projects-update.service"
        ];
        serviceConfig.Slice = "ironmain-ci-runner.slice";
      };

      environment.etc."ironmain-ci-slots/layout.json".text = builtins.toJSON layout;
    })
  ];
}

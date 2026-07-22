# /// Description: Defines the opt-in system-owned IronMain CI slot and mirror substrate.
# /// Pre: The host supplies an existing runner user/group before enabling the module.
# /// Post: Configuration exposes exactly twelve fixed slots and one root-managed read-only mirror.
# /// Reason: CI jobs need bounded private workspaces and reusable role-separated artifacts.
{ config, lib, pkgs, ... }:
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
  invocationBroker = pkgs.writeShellApplication {
    name = "ironmain-ci-invocation-broker";
    runtimeInputs = [
      helper
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
      if [ "''${SUDO_USER:-}" = ${lib.escapeShellArg cfg.runnerUser} ]; then
        slice=ironmain-ci-runner-invocations.slice
      elif [ "''${SUDO_USER:-}" = ${lib.escapeShellArg cfg.localUser} ]; then
        slice=ironmain-ci-local-invocations.slice
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

      # /// Description: Stops the exact transient invocation when its waiting caller is cancelled.
      # /// Pre: A trusted invocation unit may be starting or active under systemd_run_pid.
      # /// Post: No child remains in the unit; the broker returns the conventional signal status.
      # /// Reason: Killing systemd-run alone does not stop the system-owned transient service.
      cancel() {
        cancellation_status="$1"
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
        --setenv="IRONMAIN_CI_BROKER_INVOCATION=$invocation" \
        ${helper}/bin/ironmain-ci-slots \
        --root ${lib.escapeShellArg cfg.root} \
        run \
        --invocation-id "$invocation" \
        --register-helper ${rootRegistrar}/bin/ironmain-ci-root-registrar \
        "$@" &
      systemd_run_pid=$!
      if [ "$cancellation_status" -ne 0 ]; then
        cancel "$cancellation_status"
      fi
      set +e
      wait "$systemd_run_pid"
      status=$?
      set -e
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
    ];
    text = ''
      if [ ! -f ${lib.escapeShellArg "${cfg.root}/mirror.git/HEAD"} ]; then
        git init --bare ${lib.escapeShellArg "${cfg.root}/mirror.git"}
      fi
      if git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} remote get-url origin >/dev/null 2>&1; then
        git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} remote set-url origin ${lib.escapeShellArg cfg.mirrorSource}
      else
        git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} remote add origin ${lib.escapeShellArg cfg.mirrorSource}
      fi
      git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} \
        fetch \
        --upload-pack=${lib.escapeShellArg mirrorUploadPack} \
        --prune \
        origin \
        '+refs/*:refs/*'
      chown -R root:${lib.escapeShellArg cfg.runnerGroup} ${lib.escapeShellArg "${cfg.root}/mirror.git"}
      chmod -R g-w,o-rwx ${lib.escapeShellArg "${cfg.root}/mirror.git"}
      chmod 0750 ${lib.escapeShellArg "${cfg.root}/mirror.git"}
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
      chown -R root:root ${lib.escapeShellArg "${cfg.root}/locks"} ${lib.escapeShellArg "${cfg.root}/registry"}
      chmod 0555 ${lib.escapeShellArg "${cfg.root}/locks"} ${lib.escapeShellArg "${cfg.root}/registry"}
      chmod 0750 ${lib.escapeShellArg "${cfg.root}/mirror.git"}
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
      system.build.ironmainCiSlotsLayout = pkgs.writeText "ironmain-ci-slots-layout.json" (builtins.toJSON layout);
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
        after = [ "ironmain-ci-mirror-update.service" ];
        requires = [ "ironmain-ci-mirror-update.service" ];
        serviceConfig.Slice = "ironmain-ci-runner.slice";
      };
      systemd.services."gitea-runner-desktop\\x2ddocker" = {
        after = [ "ironmain-ci-mirror-update.service" ];
        requires = [ "ironmain-ci-mirror-update.service" ];
        serviceConfig.Slice = "ironmain-ci-runner.slice";
      };

      environment.etc."ironmain-ci-slots/layout.json".text = builtins.toJSON layout;
    })
  ];
}

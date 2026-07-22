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
      runner = "ironmain-ci-runner.slice";
      local = "ironmain-ci-local.slice";
    };
  };
  helper = pkgs.writeShellApplication {
    name = "ironmain-ci-slots";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../scripts/ironmain_ci_slots.py} "$@"
    '';
  };
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
      git --git-dir=${lib.escapeShellArg "${cfg.root}/mirror.git"} fetch --prune origin '+refs/*:refs/*'
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

    mirrorSource = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3010/jrestivo/ironmain.git";
      description = "Local Forgejo URL used by root to refresh the job-read-only mirror without credentials.";
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
      environment.systemPackages = [ helper ];

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

      systemd.slices.ironmain-ci-runner.sliceConfig = {
        IOAccounting = true;
        CPUAccounting = true;
        MemoryAccounting = true;
      };
      systemd.user.slices.ironmain-ci-local.sliceConfig = {
        IOAccounting = true;
        CPUAccounting = true;
        MemoryAccounting = true;
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

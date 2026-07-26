{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    hasPrefix
    listToAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    types
    unique
    ;
  cfg = config.custom_modules.user_io_budget;

  resolvedUsers = mapAttrsToList (name: userCfg: {
    inherit name;
    inherit (userCfg) uid;
    daily_bytes = if userCfg.dailyBytes == null then cfg.dailyBytes else userCfg.dailyBytes;
  }) cfg.users;

  controllerConfig = pkgs.writeText "user-io-budget.json" (builtins.toJSON {
    devices = cfg.devices;
    users = resolvedUsers;
    daily_bytes = cfg.dailyBytes;
    burst_bps = cfg.burstBytesPerSecond;
    exhausted_bps = cfg.exhaustedBytesPerSecond;
    warning_percentages = cfg.warningPercentages;
    terminal_notifications = cfg.terminalNotifications;
  });

  controller = pkgs.writeShellScript "user-io-budget" ''
    exec ${pkgs.python3}/bin/python3 ${../scripts/user_io_budget.py} "$@"
  '';
in
{
  options.custom_modules.user_io_budget = {
    enable = mkEnableOption "per-user daily cgroup-v2 physical write budgets";

    users = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          uid = mkOption {
            type = types.ints.positive;
            description = "Deployed numeric UID used in the user slice name.";
          };

          dailyBytes = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
            description = "Optional per-user daily write budget override in bytes.";
          };
        };
      });
      default = { };
      description = "Normal users whose user slices receive write budgets.";
    };

    devices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "/dev/nvme0n1"
        "/dev/nvme1n1"
      ];
      description = "Physical block devices included in accounting and enforcement.";
    };

    dailyBytes = mkOption {
      type = types.ints.positive;
      default = 500 * 1000 * 1000 * 1000;
      description = "Default combined daily physical write budget per user in bytes.";
    };

    burstBytesPerSecond = mkOption {
      type = types.ints.positive;
      default = 20 * 1000 * 1000;
      description = "Maximum write bandwidth per configured device before budget exhaustion.";
    };

    exhaustedBytesPerSecond = mkOption {
      type = types.ints.positive;
      default = 100 * 1000;
      description = "Maximum write bandwidth per configured device after budget exhaustion.";
    };

    warningPercentages = mkOption {
      type = types.listOf (types.ints.between 1 99);
      default = [
        50
        75
        90
      ];
      description = "Usage percentages that produce one warning per user and day.";
    };

    terminalNotifications = mkOption {
      type = types.bool;
      default = true;
      description = "Write threshold warnings to every active pseudoterminal owned by the affected user.";
    };

    interval = mkOption {
      type = types.str;
      default = "10min";
      description = "Monotonic interval between budget accounting runs.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.custom_modules.monitoring.enable;
        message = "custom_modules.user_io_budget requires monitoring for the Prometheus textfile directory";
      }
      {
        assertion = cfg.devices != [ ];
        message = "custom_modules.user_io_budget.devices must contain at least one physical block device";
      }
      {
        assertion = cfg.users != { };
        message = "custom_modules.user_io_budget.users must contain at least one user";
      }
      {
        assertion = builtins.all (device: hasPrefix "/dev/" device) cfg.devices;
        message = "every user I/O budget device must be an absolute /dev path";
      }
      {
        assertion = builtins.length (unique (map (user: user.uid) resolvedUsers)) == builtins.length resolvedUsers;
        message = "user I/O budget UIDs must be unique";
      }
      {
        assertion = builtins.length (unique cfg.warningPercentages) == builtins.length cfg.warningPercentages;
        message = "user I/O budget warning percentages must be unique";
      }
      {
        assertion = builtins.all (
          user:
          builtins.hasAttr user.name config.users.users
          && config.users.users.${user.name}.uid == user.uid
        ) resolvedUsers;
        message = "every user I/O budget UID must match the UID pinned in users.users";
      }
      {
        assertion = cfg.exhaustedBytesPerSecond < cfg.burstBytesPerSecond;
        message = "the exhausted write rate must be lower than the normal burst rate";
      }
    ];

    systemd.slices = listToAttrs (
      map (
        user:
        nameValuePair "user-${toString user.uid}" {
          description = "Persistent user slice for ${user.name} with physical write burst limits";
          wantedBy = [ "slices.target" ];
          sliceConfig = {
            IOAccounting = true;
            IOWriteBandwidthMax = map (
              device: "${device} ${toString cfg.burstBytesPerSecond}"
            ) cfg.devices;
          };
        }
      ) resolvedUsers
    );

    systemd.services.user-io-budget = {
      description = "Account and enforce per-user daily physical write budgets";
      wantedBy = [ "multi-user.target" ];
      before = [ "systemd-user-sessions.service" ];
      after = [
        "local-fs.target"
        "slices.target"
        "systemd-tmpfiles-setup.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${controller} \
            --config ${controllerConfig} \
            --state /var/lib/user-io-budget/state.json \
            --metrics /var/lib/node_exporter/textfile_collector/user_io_budget.prom
        '';
        StateDirectory = "user-io-budget";
        StateDirectoryMode = "0700";
        UMask = "0022";
        Nice = 10;
        IOSchedulingClass = "idle";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = false;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        CapabilityBoundingSet = "";
        SupplementaryGroups = [ "tty" ];
        ReadWritePaths = [ "/var/lib/node_exporter/textfile_collector" ];
      };
    };

    systemd.timers.user-io-budget = {
      description = "Check per-user daily physical write budgets every ${cfg.interval}";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        AccuracySec = "30s";
        Unit = "user-io-budget.service";
      };
    };
  };
}

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
  };
  helper = pkgs.writeShellApplication {
    name = "ironmain-ci-slots";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../scripts/ironmain_ci_slots.py} "$@"
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
        "d ${cfg.root}/slots 0770 ${cfg.runnerUser} ${cfg.runnerGroup} -"
      ];

      systemd.services.ironmain-ci-slots-provision = {
        description = "Provision bounded IronMain CI slots";
        wantedBy = [ "multi-user.target" ];
        before = [ "gitea-runner-desktop.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
          Group = "root";
          UMask = "0007";
          ExecStart = "${provision}/bin/ironmain-ci-slots-provision";
        };
      };

      environment.etc."ironmain-ci-slots/layout.json".text = builtins.toJSON layout;
    })
  ];
}

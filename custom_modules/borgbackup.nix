{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    mapAttrs
    mapAttrs'
    nameValuePair
    escapeShellArg
    optionalAttrs
    ;
  cfg = config.custom_modules.borgbackup;
  pgPkg = config.services.postgresql.package;
  passCommand = "${pkgs.age}/bin/age -d -i ${cfg.identityFile} ${cfg.passphraseAgeFile}";
in
{
  options.custom_modules.borgbackup = {
    enable = mkEnableOption "encrypted BorgBackup for Plane and Forgejo";

    passphraseAgeFile = mkOption {
      type = types.str;
      default = "/etc/borg/passphrase.age";
      description = "Path to age-encrypted Borg passphrase. Any enrolled recipient can decrypt.";
    };

    identityFile = mkOption {
      type = types.str;
      default = "/etc/borg/age-identity.txt";
      description = "Local age identity file for automated passphrase decryption.";
    };

    repos = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          path = mkOption {
            type = types.str;
            description = "Borg repo path (local path or ssh://user@host/path).";
          };
          sshKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "SSH private key for remote repositories.";
          };
          startAt = mkOption {
            type = types.str;
            default = "*-*-* 04:00:00";
            description = "systemd calendar expression for backup schedule.";
          };
        };
      });
      default = { };
      description = "Backup destinations. Each entry creates an independent Borg job.";
    };

    prune = {
      daily = mkOption {
        type = types.int;
        default = 7;
      };
      weekly = mkOption {
        type = types.int;
        default = 4;
      };
      monthly = mkOption {
        type = types.int;
        default = 6;
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.borgbackup
      pkgs.age
      pkgs.age-plugin-yubikey
    ];

    # Directory for pre-backup database dumps
    systemd.tmpfiles.rules = [
      "d /var/backup/postgres 0700 root root -"
    ];

    # Auto-initialize repos on first backup trigger
    systemd.services = mapAttrs' (name: repoCfg:
      nameValuePair "borgbackup-init-${name}" {
        description = "Auto-initialize Borg repo ${name} if needed";
        requiredBy = [ "borgbackup-job-${name}.service" ];
        before = [ "borgbackup-job-${name}.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        environment = {
          BORG_PASSCOMMAND = passCommand;
        } // optionalAttrs (repoCfg.sshKey != null) {
          BORG_RSH = "ssh -i ${repoCfg.sshKey}";
        };
        path = [ pkgs.borgbackup pkgs.age ];
        script = ''
          if [ ! -f "${cfg.passphraseAgeFile}" ]; then
            echo "Borg not configured yet — run setup-borg-backup.sh first"
            exit 0
          fi
          if ! borg info ${escapeShellArg repoCfg.path} &>/dev/null; then
            echo "Initializing Borg repo: ${repoCfg.path}"
            borg init --encryption=repokey-blake2 ${escapeShellArg repoCfg.path}
          fi
        '';
      }
    ) cfg.repos;

    services.borgbackup.jobs = mapAttrs (_name: repoCfg: {
      paths = [
        "/var/lib/forgejo"
        "/var/lib/plane"
        "/var/backup/postgres"
      ];
      exclude = [
        "/var/lib/forgejo/dump"
      ];
      repo = repoCfg.path;
      encryption = {
        mode = "repokey-blake2";
        passCommand = passCommand;
      };
      compression = "auto,zstd,22";
      startAt = repoCfg.startAt;
      preHook = ''
        set -o pipefail
        ${pkgs.sudo}/bin/sudo -u postgres ${pgPkg}/bin/pg_dump forgejo \
          | ${pkgs.zstd}/bin/zstd > /var/backup/postgres/forgejo.sql.zst.tmp
        mv /var/backup/postgres/forgejo.sql.zst.tmp /var/backup/postgres/forgejo.sql.zst
        ${pkgs.sudo}/bin/sudo -u postgres ${pgPkg}/bin/pg_dump plane \
          | ${pkgs.zstd}/bin/zstd > /var/backup/postgres/plane.sql.zst.tmp
        mv /var/backup/postgres/plane.sql.zst.tmp /var/backup/postgres/plane.sql.zst
      '';
      prune.keep = {
        daily = cfg.prune.daily;
        weekly = cfg.prune.weekly;
        monthly = cfg.prune.monthly;
      };
      environment = optionalAttrs (repoCfg.sshKey != null) {
        BORG_RSH = "ssh -i ${repoCfg.sshKey}";
      };
    }) cfg.repos;
  };
}

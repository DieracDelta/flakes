{
  config,
  pkgs,
  lib,
  nixpkgs-master,
  system,
  ...
}:
with lib;
let
  cfg = config.custom_modules.jellyfin;
  ##### SPOTIZERR
  redis-port = 32141;

  # Directory paths
  spotizerrStateDir = "/var/lib/spotizerr";
  musicLibraryDir = "/var/lib/musiclibrary";
  redisPasswordDir = "/var/lib/redis-spotizerr";
  redisPasswordFile = "${redisPasswordDir}/password";
  spotizerrEnvFile = "${spotizerrStateDir}/.env";
  spotizerrLogDir = "/var/lib/spotizzer_logs";
  spotizerrDataDir = "/var/lib/spotizerr_data";

  # User/group references
  mediaGroup = "jellyfin";
  spotizerrUid = 32141;
  mediaGid = 979;
in
{
  options.custom_modules.jellyfin.enable = mkOption {
    description = "Enable custom Jellyfin configuration.";
    type = with types; bool;
    default = false;
  };

  config = mkIf cfg.enable {
    services.navidrome.enable = true;
    services.navidrome.user = "jellyfin";
    services.navidrome.group = "jellyfin";
    services.navidrome.openFirewall = true;
    services.navidrome.settings.Address = "127.0.0.1";
    services.navidrome.settings."Scanner.FollowSymlinks" = true;
    services.navidrome.settings.Port = 4533;
    services.navidrome.settings.MusicFolder = "/var/lib/musiclibrary";
    services.navidrome.package = pkgs.navidrome.override {
      plugins = with pkgs.navidromePlugins; [ discord-rich-presence ];
    };
    services.navidrome.settings.BaseUrl = "/navidrome";
    services.navidrome.settings.Plugins.Enabled = true;
    services.navidrome.settings.Plugins.Folder = "${config.services.navidrome.package}/share/plugins";
    systemd.services.navidrome.serviceConfig.BindReadOnlyPaths = [ "/var/lib/musiclibrary" ];

    services.jellyfin.enable = false;
    users.groups.jellyfin = { };
    # services.jellyfin.user = "jrestivo";
    # per https://jellyfin.org/docs/general/networking/index.html

    networking.firewall.allowedTCPPorts = [
      # open ssh ports
      22
      24
      200
      201
      202
      443
      2001
      2002
      2022

      # other ports
      2019
      32141
      8096
      4533
      8920
      7171
      28981
      6969
      8000
      8181
      1234
      2345
      3141
      31415
      47984
      1618
      16180
      3000
      48011
      48006
      48012
      48010
      48032
    ];
    networking.firewall.allowedUDPPorts = [
      # open ssh ports
      22
      24
      200
      201
      202
      443
      2001
      2002
      2022

      2019 # caddy

      # other ports
      48000
      48010
      47984
      48006
      48012
      48032
      48011
      1900
      4533
      7359
      28981
      6969
      8000
      8181
      2345
    ];

    # copied from https://github.com/miniluz/nixos-config/blob/main/modules/nixos/selfhosting/jellyfin/spotizerr.nix
    # thank you !!

    users.users.spotizerr = {
      uid = spotizerrUid;
      group = "spotizerr";
      extraGroups = [ mediaGroup ];

      isSystemUser = true;

      home = spotizerrStateDir;
      createHome = true;
    };

    users.users.jellyfin = {
      uid = 984;
      group = "jellyfin";
      extraGroups = [ "spotizerr" ];
      createHome = false;
    };

    users.groups.spotizerr.gid = spotizerrUid;

    systemd.tmpfiles.rules = [
      # Music library on HDD with symlink from /var/lib/musiclibrary
      "d /storage/media/musiclibrary 0775 spotizerr ${mediaGroup} -"
      "L+ ${musicLibraryDir} - - - - /storage/media/musiclibrary"
      "d ${spotizerrLogDir} 0700 spotizerr spotizerr -"
      "d ${spotizerrDataDir} 0700 spotizerr spotizerr -"
      "d ${redisPasswordDir} 0750 redis-spotizerr redis-spotizerr -"
    ];

    systemd.services.spotizerr-password-generator = {
      description = "Generate Redis password for Spotizerr";
      wantedBy = [ "multi-user.target" ];
      before = [
        "redis-spotizerr.service"
        "quadlet-spotizerr-app.service"
      ];
      requires = [ "systemd-tmpfiles-setup.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
      };

      script = ''
                set -euo pipefail

                # Set secure file creation mask
                umask 077

                echo "Setting up Spotizerr Redis authentication..."

                # Generate password if it doesn't exist
                if [ ! -f "${redisPasswordFile}" ]; then
                  echo "Generating new Redis password..."
                  if ! ${pkgs.openssl}/bin/openssl rand -base64 32 > "${redisPasswordFile}"; then
                    echo "ERROR: Failed to generate Redis password" >&2
                    exit 1
                  fi
                  echo "Redis password generated successfully"
                else
                  echo "Redis password already exists, skipping generation"
                fi

                # Set secure permissions for Redis password file
                chown redis-spotizerr:redis-spotizerr "${redisPasswordFile}"
                chmod 400 "${redisPasswordFile}"

                # Create environment file for container
                echo "Creating Spotizerr environment file..."
                cat > "${spotizerrEnvFile}" << EOF
        REDIS_PASSWORD=$(cat "${redisPasswordFile}")
        EOF

                # Set secure permissions for environment file
                chown spotizerr:spotizerr "${spotizerrEnvFile}"
                chmod 600 "${spotizerrEnvFile}"

                echo "Spotizerr authentication setup completed"
      '';
    };

    services.redis.servers.spotizerr = {
      enable = true;
      port = redis-port;
      bind = "127.0.0.1";
      requirePassFile = redisPasswordFile;
    };

    # Ensure Redis waits for password generation
    systemd.services.redis-spotizerr = {
      requires = [ "spotizerr-password-generator.service" ];
      after = [ "spotizerr-password-generator.service" ];
    };

    virtualisation.quadlet.containers.spotizerr-app = {
      autoStart = true;

      containerConfig = {
        image = "lavaforge.org/spotizerr/spotizerr";
        publishPorts = [ "7171:7171" ];

        # needed to access redis on host
        networks = [ "host" ];

        environments = {
          HOST = "0.0.0.0";

          REDIS_HOST = "127.0.0.1";
          REDIS_PORT = toString redis-port;
          REDIS_DB = "0";

          PUID = toString spotizerrUid;
          PGID = toString mediaGid;
        };

        environmentFiles = [ spotizerrEnvFile ];

        volumes = [
          "${spotizerrDataDir}:/app/data"
          "${spotizerrLogDir}:/app/logs"

          "${musicLibraryDir}:/app/downloads"
        ];
      };

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10";
      };

      unitConfig = {
        Requires = [
          "redis-spotizerr.service"
          "spotizerr-password-generator.service"
        ];
        After = [
          "redis-spotizerr.service"
          "spotizerr-password-generator.service"
        ];
      };
    };

    services.paperless = {
      enable = true;
      # passwordFile = "/etc/paperless-admin-pass";
      port = 28981;
      # dataDir = "/var/lib/paperless";
      # mediaDir = "/var/lib/paperless/media";
      # consumptionDir = "/var/lib/paperless/in";
      # consumptionDirIsPublic = true;
      address = "0.0.0.0";
      settings = {
        # 1. This is the Magic Switch: Tells Paperless "I live in this folder"
        PAPERLESS_FORCE_SCRIPT_NAME = "/paperless";
        PAPERLESS_STATIC_URL = "/paperless/static/";

        # 2. Your full public URL (Must include /paperless at the end)
        PAPERLESS_URL = "https://office-desktop.tail5ca7.ts.net";

        # 3. Security settings to allow the connection
        PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://office-desktop.tail5ca7.ts.net";
        PAPERLESS_CORS_ALLOWED_ORIGINS = "https://office-desktop.tail5ca7.ts.net";
        PAPERLESS_ALLOWED_HOSTS = "office-desktop.tail5ca7.ts.net,localhost,127.0.0.1";
        PAPERLESS_DISABLE_REGULAR_LOGIN = true;
        PAPERLESS_ENABLE_HTTP_REMOTE_USER = true;
      };
    };
    users.users.paperless = {
      shell = pkgs.bashInteractive;
      isSystemUser = true;
    };
    services.immich = {
      enable = false;
      port = 2283;
      openFirewall = true;
      accelerationDevices = null;
      host = "0.0.0.0";
    };

    services.vnstat.enable = true;
    services.ntopng.enable = true;
    services.ntopng.httpPort = 3123;
    services.ntopng.extraConfig = ''
      --http-prefix="/ntopng"
    '';

    services.opensnitch.enable = false;

    # programs.atop.enable = true;
    # programs.atop.netatop.enable = true;

    # users = {
    #   jrestivo = {
    #     # passwordFile = config.age.secrets.nut-password.path;
    #     upsmon = "primary";
    #   };
    # };

    # services.prometheus.exporters.

    # users.users.immich.extraGroups = [
    #   "video"
    #   "render"
    # ];
  };
}

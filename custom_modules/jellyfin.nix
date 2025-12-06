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
    services.navidrome.settings.Address = "0.0.0.0";
    services.navidrome.settings."Scanner.FollowSymlinks" = true;
    services.navidrome.settings.MusicFolder = "/jellyfin/MUSIC";
    services.navidrome.package = nixpkgs-master.legacyPackages.${system}.navidrome;
    systemd.services.navidrome.serviceConfig.BindReadOnlyPaths = [ "/var/lib/musiclibrary" ];

    services.jellyfin.enable = false;
    users.groups.jellyfin = { };
    # services.jellyfin.user = "jrestivo";
    # per https://jellyfin.org/docs/general/networking/index.html

    networking.firewall.allowedTCPPorts = [
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
      "d ${musicLibraryDir} 0775 spotizerr ${mediaGroup} -"
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

    power.ups = {
      enable = true;
      mode = "netserver";
      ups.eaton5sc = {
        driver = "usbhid-ups";
        port = "auto";
        directives = [
          "vendorid = 0463"
          "productid = ffff"
        ];
        description = "Eaton 5SC1000";
      };

      upsd.listen = [
        {
          address = "0.0.0.0";
          port = 1618;
        }
      ];

      upsmon.monitor.eaton5sc = {
        user = "monuser";
        system = "eaton5sc@127.0.0.1:1618";
        type = "primary";
      };

      users.monuser = {
        passwordFile = "/etc/nut/mon.pw";
        upsmon = "primary";
      };

      openFirewall = true;

    };

    environment.etc."nut/mon.pw" = {
      text = "password";
      mode = "0600";
      user = "root";
      group = "nut";
    };

    services.prometheus.exporters.nut = {
      enable = true;
      nutServer = "127.0.0.1";
      extraFlags = [
        "--nut.serverport=1618"
        # "--metrics.namespace=nut"
        "--nut.vars_enable="
      ];
      port = 16180;
      listenAddress = "0.0.0.0";
    };

    services.prometheus = {
      enable = true;
      scrapeConfigs = [
        {
          job_name = "nut";
          metrics_path = "/ups_metrics";
          static_configs = [
            {
              targets = [ "127.0.0.1:16180" ];
              # labels.ups = "eaton5sc";
            }
          ];
          # metric_relabel_configs = [
          #   {
          #     action = "drop";
          #     source_labels = [ "ups" ];
          #     regex = ""; # if label missing, value is empty — match and drop
          #   }
          # ];
        }
      ];
    };
    services.grafana = {
      enable = true;
      settings.server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
      # 1) Tell Grafana where to read dashboards from
      provision.dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "mynutdashboard";
            orgId = 1;
            folder = "NUT";
            type = "file";
            disableDeletion = false;
            editable = true;
            options = {
              path = "/etc/grafana-dashboards/nut";
            };
          }
        ];
      };

      # 2) Provision Prometheus datasource (so the dashboard has data)
      provision.datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:9090";
            access = "proxy";
            isDefault = true;
          }
        ];
        # {
        #   name = "Prometheus";
        #   type = "prometheus";
        #   access = "proxy";
        #   url = "http://127.0.0.1:9090";
        #   isDefault = true;
        # }
      };
    };
    # TODO fix
    environment.etc."grafana-dashboards/nut/mynutdashboard.json" = {
      text =
        let
          raw = builtins.fetchurl {
            url = "https://grafana.com/api/dashboards/15406/revisions/1/download";
            sha256 = "1pvyyxyy6prd0aqkvki04ayr4sw2rfyzx9gc3scyhzjy6rq648ca";
          };
          fixed = builtins.replaceStrings [ "$${DS_PROMETHEUS}" ] [ "Prometheus" ] (builtins.readFile raw);
        in
        fixed;
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };

    systemd.services.upsmon.serviceConfig.LogNamespace = "power";
    systemd.services.upsd.serviceConfig.LogNamespace = "power";
    # The "@" targets the template, covering nut-driver@eaton5sc and any others
    systemd.services."nut-driver@".serviceConfig.LogNamespace = "power";

    environment.etc."systemd/journald@power.conf".text = ''
      [Journal]
      MaxRetentionSec=infinity
      SystemMaxUse=500G
      Storage=persistent
    '';

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

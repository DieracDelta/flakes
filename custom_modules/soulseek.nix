{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom_modules.soulseek;
  quadlet = config.virtualisation.quadlet;
  inherit (quadlet) containers pods;

  slskdConfig = (pkgs.formats.yaml { }).generate "slskd.yml" {
    directories = {
      downloads = "/downloads";
      incomplete = "/incomplete";
    };
    shares = {
      directories = [ ];
      filters = [
        "\\.DS_Store$"
        "Thumbs.db$"
        "\\.ini$"
      ];
    };
    soulseek = {
      listen_port = cfg.listenPort;
      description = "slskd on NixOS via Tailscale Mullvad";
    };
    flags.force_share_scan = false;
    web = {
      port = 5030;
      url_base = cfg.basePath;
      https.disabled = true;
    };
    logger.disk = false;
  };
in
{
  options.custom_modules.soulseek = {
    enable = lib.mkEnableOption "Soulseek via slskd in a Tailscale-routed Quadlet pod";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "office-desktop.tail5ca7.ts.net";
      description = "Caddy virtual host to expose the slskd web UI on.";
    };

    basePath = lib.mkOption {
      type = lib.types.str;
      default = "/slskd";
      description = "URL base path for the slskd web UI.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "username";
      description = "Soulseek and slskd web UI username.";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "password";
      description = "Soulseek and slskd web UI password.";
    };

    slskdImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/slskd/slskd:latest";
      description = "Container image used for slskd.";
    };

    tailscaleImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/tailscale/tailscale:stable";
      description = "Container image used for the Tailscale sidecar.";
    };

    tailscaleHostname = lib.mkOption {
      type = lib.types.str;
      default = "office-desktop-slskd";
      description = "Tailnet device name for the slskd Tailscale sidecar.";
    };

    tailscaleExitNode = lib.mkOption {
      type = lib.types.str;
      default = "100.65.194.122";
      description = "Mullvad exit node used by the slskd pod.";
    };

    tailscaleEnvironmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional env file for the Tailscale container, for example one containing TS_AUTHKEY=...";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/storage/media/soulseek/slskd";
      description = "Persistent slskd application state directory.";
    };

    tailscaleStateDir = lib.mkOption {
      type = lib.types.str;
      default = "/storage/media/soulseek/tailscale";
      description = "Persistent Tailscale state directory for the slskd sidecar.";
    };

    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/storage/media/soulseek/downloads";
      description = "Directory for completed Soulseek downloads.";
    };

    incompleteDir = lib.mkOption {
      type = lib.types.str;
      default = "/storage/media/soulseek/incomplete";
      description = "Directory for incomplete Soulseek downloads.";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 5030;
      description = "Local host port for the slskd web UI.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 50300;
      description = "Soulseek network listen port inside the slskd pod.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.quadlet.autoEscape = true;

    systemd.tmpfiles.rules = [
      "d /storage/media/soulseek 0775 jrestivo users -"
      "d ${cfg.stateDir} 0750 root root -"
      "d ${cfg.tailscaleStateDir} 0750 root root -"
      "d ${cfg.downloadDir} 0775 jrestivo users -"
      "d ${cfg.incompleteDir} 0775 jrestivo users -"
    ];

    virtualisation.quadlet = {
      pods.soulseek.podConfig = {
        name = "soulseek";
        publishPorts = [ "127.0.0.1:${toString cfg.webPort}:5030" ];
      };

      containers."soulseek-tailscale" = {
        containerConfig = {
          name = "soulseek-tailscale";
          image = cfg.tailscaleImage;
          pod = pods.soulseek.ref;
          addCapabilities = [
            "NET_ADMIN"
            "NET_RAW"
          ];
          devices = [ "/dev/net/tun:/dev/net/tun" ];
          volumes = [ "${cfg.tailscaleStateDir}:/var/lib/tailscale" ];
          environments = {
            TS_ACCEPT_DNS = "true";
            TS_DEBUG_FIREWALL_MODE = "nftables";
            TS_HOSTNAME = cfg.tailscaleHostname;
            TS_EXTRA_ARGS = "--exit-node=${cfg.tailscaleExitNode} --exit-node-allow-lan-access=true";
            TS_STATE_DIR = "/var/lib/tailscale";
            TS_USERSPACE = "false";
          };
          environmentFiles = lib.optional (cfg.tailscaleEnvironmentFile != null) cfg.tailscaleEnvironmentFile;
        };
      };

      containers."soulseek-slskd" = {
        unitConfig = {
          BindsTo = [ containers."soulseek-tailscale".ref ];
          Requires = [ containers."soulseek-tailscale".ref ];
          After = [ containers."soulseek-tailscale".ref ];
        };
        containerConfig = {
          name = "soulseek-slskd";
          image = cfg.slskdImage;
          pod = pods.soulseek.ref;
          volumes = [
            "${cfg.stateDir}:/app"
            "${slskdConfig}:/app/slskd.yml:ro"
            "${cfg.downloadDir}:/downloads"
            "${cfg.incompleteDir}:/incomplete"
          ];
          environments = {
            SLSKD_SLSK_USERNAME = cfg.username;
            SLSKD_SLSK_PASSWORD = cfg.password;
            SLSKD_USERNAME = cfg.username;
            SLSKD_PASSWORD = cfg.password;
          };
        };
      };
    };

    services.caddy.virtualHosts."${cfg.domain}".extraConfig = lib.mkAfter ''

      redir ${cfg.basePath} ${cfg.basePath}/ permanent
      handle ${cfg.basePath}/* {
        reverse_proxy 127.0.0.1:${toString cfg.webPort}
      }
    '';
  };
}

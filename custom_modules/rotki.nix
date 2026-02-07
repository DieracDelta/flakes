{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.rotki;
in
{
  options.custom_modules.rotki = {
    enable = mkEnableOption "Rotki portfolio tracker (local premium, no cloud)";

    port = mkOption {
      type = types.port;
      default = 8545;
      description = "Port for Rotki backend API";
    };

    wsPort = mkOption {
      type = types.port;
      default = 8546;
      description = "Port for Rotki WebSockets API";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/rotki";
      description = "Data directory for Rotki";
    };

    user = mkOption {
      type = types.str;
      default = "jrestivo";
      description = "User to run Rotki as (for accessing user data)";
    };
  };

  config = mkIf cfg.enable {
    # Add rotki to system packages
    environment.systemPackages = [ pkgs.rotki ];

    # Systemd service for the backend
    systemd.services.rotki = {
      description = "Rotki Portfolio Tracker";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.rotki}/bin/rotkehlchen --rest-api-port ${toString cfg.port} --websockets-api-port ${toString cfg.wsPort} --data-dir ${cfg.dataDir} --api-host 127.0.0.1 --logtarget stdout";
        WorkingDirectory = cfg.dataDir;
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
      };
    };

    # Ensure data directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} users -"
    ];

    # Caddy reverse proxy at /rotki/ subpath
    # Serves static frontend + proxies API/WebSocket to backend
    services.caddy.virtualHosts."office-desktop.tail5ca7.ts.net".extraConfig = mkAfter ''

      handle /rotki/* {
        # API requests go to backend
        @api path /rotki/api/*
        handle @api {
          uri strip_prefix /rotki
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }

        # WebSocket connections - same port as API, /ws path
        @ws path /rotki/ws /rotki/ws/*
        handle @ws {
          uri strip_prefix /rotki
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }

        # Static frontend files
        handle {
          uri strip_prefix /rotki
          root * ${pkgs.rotki-frontend}
          file_server
          try_files {path} /index.html
        }
      }
      redir /rotki /rotki/ permanent
    '';

    # Homepage dashboard entry
    services.homepage-dashboard.services = mkAfter [
      {
        "Crypto" = [
          {
            "Rotki" = {
              icon = "rotki";
              href = "/rotki/";
              description = "Portfolio Tracker & Accounting";
            };
          }
        ];
      }
    ];
  };
}

{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.multi-scrobbler;
  stateDir = "/var/lib/multi-scrobbler";
in
{
  options.custom_modules.multi-scrobbler = {
    enable = mkEnableOption "Multi-scrobbler service";

    port = mkOption {
      type = types.port;
      default = 9078;
      description = "Port for multi-scrobbler web UI";
    };

    baseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Base URL for multi-scrobbler (for OAuth callbacks)";
    };
  };

  config = mkIf cfg.enable {
    # User/Group
    users.users.multi-scrobbler = {
      isSystemUser = true;
      group = "multi-scrobbler";
      home = stateDir;
      createHome = true;
      description = "Multi-scrobbler service user";
    };
    users.groups.multi-scrobbler = { };

    # Directory setup
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 multi-scrobbler multi-scrobbler -"
    ];

    # Multi-scrobbler service
    systemd.services.multi-scrobbler = {
      description = "Multi-Scrobbler";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        NODE_ENV = "production";
        CONFIG_DIR = stateDir;
        PORT = toString cfg.port;
        BASE_URL = if cfg.baseUrl != null then cfg.baseUrl else "http://127.0.0.1:${toString cfg.port}";
      };

      serviceConfig = {
        Type = "simple";
        User = "multi-scrobbler";
        Group = "multi-scrobbler";
        ExecStart = "${pkgs.multi-scrobbler}/bin/multi-scrobbler";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ stateDir ];
      };
    };
  };
}

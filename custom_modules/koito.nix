{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.koito;
  stateDir = "/var/lib/koito";
  configDir = "${stateDir}/config";
  dbName = "koito"; # Must match dbUser for ensureDBOwnership
  dbUser = "koito";
in
{
  options.custom_modules.koito = {
    enable = mkEnableOption "Koito scrobbler service";

    port = mkOption {
      type = types.port;
      default = 4110;
      description = "Port for Koito to listen on";
    };

    allowedHosts = mkOption {
      type = types.str;
      default = "office-desktop.tail5ca7.ts.net,localhost,127.0.0.1";
      description = "Comma-separated list of allowed hosts";
    };

    subsonicUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Subsonic server URL (for artwork fetching from Navidrome)";
    };

    subsonicParamsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing KOITO_SUBSONIC_PARAMS (u=user&t=token&s=salt)";
    };

    defaultUsername = mkOption {
      type = types.str;
      default = "admin";
      description = "Default admin username";
    };

    defaultPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing default admin password";
    };

    configureNavidrome = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically configure Navidrome to scrobble to Koito";
    };
  };

  config = mkIf cfg.enable {
    # User/Group
    users.users.koito = {
      isSystemUser = true;
      group = "koito";
      home = stateDir;
      createHome = true;
      description = "Koito scrobbler service user";
    };
    users.groups.koito = { };

    # Directory setup
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 koito koito -"
      "d ${configDir} 0750 koito koito -"
      "d ${configDir}/import 0750 koito koito -"
      "d ${configDir}/images 0750 koito koito -"
    ];

    # PostgreSQL (use nixpkgs default - Koito requires 16+, nixpkgs has 17)
    services.postgresql.enable = true;
    services.postgresql.ensureDatabases = [ dbName ];
    services.postgresql.ensureUsers = [
      {
        name = dbUser;
        ensureDBOwnership = true;
      }
    ];
    services.postgresql.authentication = mkAfter ''
      local ${dbName} ${dbUser} peer
    '';

    # Koito service
    systemd.services.koito = {
      description = "Koito ListenBrainz Scrobbler";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "postgresql.service"
      ];
      requires = [ "postgresql.service" ];

      environment =
        {
          KOITO_DATABASE_URL = "postgres:///${dbName}?host=/run/postgresql";
          KOITO_ALLOWED_HOSTS = cfg.allowedHosts;
          KOITO_LISTEN_PORT = toString cfg.port;
          KOITO_CONFIG_DIR = configDir;
          KOITO_BIND_ADDR = "127.0.0.1";
          KOITO_LOG_LEVEL = "info";
          KOITO_DEFAULT_USERNAME = cfg.defaultUsername;
        }
        // optionalAttrs (cfg.subsonicUrl != null) {
          KOITO_SUBSONIC_URL = cfg.subsonicUrl;
        };

      serviceConfig = {
        Type = "simple";
        User = "koito";
        Group = "koito";
        WorkingDirectory = "${pkgs.koito}/share/koito";
        ExecStart = "${pkgs.koito}/bin/koito";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ stateDir ];

        # Environment files for secrets
        EnvironmentFile = mkIf (cfg.subsonicParamsFile != null) [
          cfg.subsonicParamsFile
        ];

        # Load password from file if specified
        LoadCredential = mkIf (cfg.defaultPasswordFile != null) [
          "password:${cfg.defaultPasswordFile}"
        ];
      };

      # Set default password from credential if provided
      preStart = mkIf (cfg.defaultPasswordFile != null) ''
        if [ -f "$CREDENTIALS_DIRECTORY/password" ]; then
          export KOITO_DEFAULT_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/password")
        fi
      '';
    };

    # Configure Navidrome to scrobble to Koito (skip if multi-scrobbler handles it)
    services.navidrome.settings = mkIf (cfg.configureNavidrome && config.services.navidrome.enable && !config.custom_modules.multi-scrobbler.enable) {
      "ListenBrainz.Enabled" = true;
      "ListenBrainz.BaseURL" = "http://127.0.0.1:${toString cfg.port}/apis/listenbrainz/1";
    };
  };
}

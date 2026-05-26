{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.audiomuse-ai-music-server;
in
{
  options.services.audiomuse-ai-music-server = {
    enable = mkEnableOption "AudioMuse-AI MusicServer";

    package = mkOption {
      type = types.package;
      default = pkgs.audiomuse-ai-music-server;
      defaultText = literalExpression "pkgs.audiomuse-ai-music-server";
      description = "AudioMuse-AI MusicServer package to run.";
    };

    port = mkOption {
      type = types.port;
      default = 9081;
      description = "Local HTTP port for the MusicServer backend.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/audiomuse-ai-music-server";
      description = "Directory for MusicServer state and SQLite database.";
    };

    musicDir = mkOption {
      type = types.path;
      default = "/var/lib/musiclibrary";
      description = "Music library path the server may scan and stream.";
    };

    user = mkOption {
      type = types.str;
      default = "audiomuse-music-server";
      description = "User to run the MusicServer as.";
    };

    group = mkOption {
      type = types.str;
      default = "audiomuse-music-server";
      description = "Group to run the MusicServer as.";
    };

    audiomuseCoreUrl = mkOption {
      type = types.nullOr types.str;
      default = "http://127.0.0.1:8000";
      description = "AudioMuse-AI core API URL used for sonic analysis features.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional environment file, for example containing AUDIO_MUSE_AI_TOKEN.";
    };

    caddy = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Expose MusicServer through Caddy with HTTPS.";
      };

      host = mkOption {
        type = types.str;
        default = "office-desktop.tail5ca7.ts.net";
        description = "Hostname for the HTTPS vhost.";
      };

      httpsPort = mkOption {
        type = types.port;
        default = 10443;
        description = "HTTPS port for the Caddy vhost.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Open the HTTPS vhost port in the firewall.";
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      extraGroups = [ "jellyfin" ];
      description = "AudioMuse-AI MusicServer service user";
    };
    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.audiomuse-ai-music-server = {
      description = "AudioMuse-AI MusicServer";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ optional config.services.audiomuse-ai.enable "audiomuse-ai.service";
      wants = optional config.services.audiomuse-ai.enable "audiomuse-ai.service";

      environment = {
        PORT = toString cfg.port;
        DATABASE_PATH = "${cfg.dataDir}/music.db";
      } // optionalAttrs (cfg.audiomuseCoreUrl != null) {
        AUDIOMUSE_AI_CORE_URL = cfg.audiomuseCoreUrl;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/audiomuse-ai-music-server";
        Restart = "on-failure";
        RestartSec = "10s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        ReadOnlyPaths = [ cfg.musicDir ];
      } // optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };

    services.caddy = mkIf cfg.caddy.enable {
      enable = mkDefault true;
      virtualHosts."${cfg.caddy.host}:${toString cfg.caddy.httpsPort}".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString cfg.port}
      '';
    };

    networking.firewall.allowedTCPPorts = mkIf (cfg.caddy.enable && cfg.caddy.openFirewall) [
      cfg.caddy.httpsPort
    ];
  };
}

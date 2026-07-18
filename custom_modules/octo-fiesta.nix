{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.octo-fiesta;
in
{
  options.custom_modules.octo-fiesta = {
    enable = mkEnableOption "Octo-Fiesta Subsonic proxy";

    package = mkOption {
      type = types.package;
      default = pkgs.octo-fiesta;
      description = "Octo-Fiesta package to run.";
    };

    port = mkOption {
      type = types.port;
      default = 5274;
      description = "Local HTTP port for Octo-Fiesta.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address Octo-Fiesta should bind to.";
    };

    musicDir = mkOption {
      type = types.path;
      default = /var/lib/musiclibrary;
      description = "Directory where Octo-Fiesta stores downloaded tracks.";
    };

    environmentFile = mkOption {
      type = types.path;
      default = /var/lib/octo-fiesta/env;
      description = "Optional systemd environment file for provider credentials and overrides.";
    };

    subsonicUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:4533";
      description = "Backing Navidrome/Subsonic URL.";
    };

    musicService = mkOption {
      type = types.enum [
        "Deezer"
        "Qobuz"
        "SquidWTF"
        "Yandex"
      ];
      default = "SquidWTF";
      description = "External music provider backend.";
    };

    caddy = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Expose Octo-Fiesta through the existing Caddy vhost.";
      };

      host = mkOption {
        type = types.str;
        default = "office-desktop.tail5ca7.ts.net";
        description = "Caddy virtual host to extend.";
      };

      basePath = mkOption {
        type = types.str;
        default = "/octo-fiesta";
        description = "Path prefix for the Octo-Fiesta reverse proxy.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasPrefix "/" cfg.caddy.basePath;
        message = "custom_modules.octo-fiesta.caddy.basePath must start with '/'.";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    systemd.tmpfiles.rules = [
      "d /var/lib/octo-fiesta 0750 jellyfin jellyfin -"
    ];

    systemd.services.octo-fiesta = {
      description = "Octo-Fiesta Subsonic proxy";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "navidrome.service"
      ];
      wants = [ "network-online.target" ];
      requires = mkIf config.services.navidrome.enable [ "navidrome.service" ];

      environment = {
        ASPNETCORE_ENVIRONMENT = "Production";
        ASPNETCORE_URLS = "http://${cfg.listenAddress}:${toString cfg.port}";
        Library__DownloadPath = toString cfg.musicDir;
        Subsonic__Url = cfg.subsonicUrl;
        Subsonic__MusicService = cfg.musicService;
        Subsonic__StorageMode = "Permanent";
        Subsonic__DownloadMode = "Track";
        Subsonic__EnableExternalPlaylists = "true";
        Subsonic__PlaylistsDirectory = "playlists";
        SquidWTF__Source = "Qobuz";
      };

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package}";
        EnvironmentFile = "-${toString cfg.environmentFile}";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "jellyfin";
        Group = "jellyfin";
        WorkingDirectory = "/var/lib/octo-fiesta";
        StateDirectory = "octo-fiesta";
        StateDirectoryMode = "0750";
      };
    };

    services.caddy.virtualHosts."${cfg.caddy.host}".extraConfig = mkIf cfg.caddy.enable (mkAfter ''
      redir ${cfg.caddy.basePath} ${cfg.caddy.basePath}/ permanent
      handle_path ${cfg.caddy.basePath}/* {
        reverse_proxy ${cfg.listenAddress}:${toString cfg.port}
      }
    '');
  };
}

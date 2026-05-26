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
  cfg = config.custom_modules.music;
  musicLibraryDir = "/var/lib/musiclibrary";
  mediaGroup = "jellyfin";
in
{
  options.custom_modules.music.enable = mkOption {
    description = "Enable music services (Navidrome, AudioMuse-AI).";
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
      plugins = with pkgs.navidromePlugins; [
        discord-rich-presence
        audiomuse-ai
      ];
    };

    # AudioMuse-AI - AI-powered music analysis for similar tracks
    services.audiomuse-ai.enable = true;
    services.audiomuse-ai.musicDir = "/var/lib/musiclibrary";
    services.audiomuse-ai.environmentFile = "/var/lib/audiomuse-ai/.env";

    # AudioMuse-AI MusicServer - Open Subsonic-compatible server and web UI
    services.audiomuse-ai-music-server = {
      enable = true;
      musicDir = "/var/lib/musiclibrary";
      environmentFile = "/var/lib/audiomuse-ai/.env";
      audiomuseCoreUrl = "http://127.0.0.1:${toString config.services.audiomuse-ai.port}";
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
      4533
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
      6969
      8000
      8181
      2345
    ];

    users.users.jellyfin = {
      uid = 984;
      group = "jellyfin";
      createHome = false;
    };

    systemd.tmpfiles.rules = [
      # Music library on HDD with symlink from /var/lib/musiclibrary
      "d /storage/media/musiclibrary 0775 jellyfin ${mediaGroup} -"
      "L+ ${musicLibraryDir} - - - - /storage/media/musiclibrary"
    ];

    services.immich = {
      enable = false;
      port = 2283;
      openFirewall = true;
      accelerationDevices = null;
      host = "0.0.0.0";
    };

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

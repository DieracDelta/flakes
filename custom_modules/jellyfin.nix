{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.jellyfin;
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
    services.navidrome.settings.MusicFolder = "/jellyfin/MUSIC";

    services.jellyfin.enable = true;
    # services.jellyfin.user = "jrestivo";
    # per https://jellyfin.org/docs/general/networking/index.html

    networking.firewall.allowedTCPPorts = [
      8096
      4533
      8920
    ];
    networking.firewall.allowedUDPPorts = [
      1900
      4533
      7359
    ];
  };
}

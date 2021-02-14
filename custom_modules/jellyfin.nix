{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.custom_modules.jellyfin;
in
{
  options.custom_modules.jellyfin.enable =
    mkOption {
      description = "Enable custom Jellyfin configuration.";
      type = with types; bool;
      default = false;
    };

  config = mkIf cfg.enable {
    services.jellyfin.enable = true;
    /*per https://jellyfin.org/docs/general/networking/index.html*/
    networking.firewall.allowedTCPPorts = [ 8096 8920 ];
    networking.firewall.allowedUDPPorts = [ 1900 7359 ];
  };
}

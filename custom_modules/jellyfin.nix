{ config, pkgs, lib, ... }:
{
  services.jellyfin.enable = true;
  /*per https://jellyfin.org/docs/general/networking/index.html*/
  networking.firewall.allowedTCPPorts = [8096 8920];
  networking.firewall.allowedUDPPorts = [1900 7359];
}

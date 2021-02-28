{ config, pkgs, lib, ... }:

{
  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./hw/oracle_vps.nix ];

  custom_modules.jellyfin.enable = false;
  custom_modules.nextcloud.enable = false;
  custom_modules.core_services.enable = true;
  custom_modules.workstation_services.enable = false;
  custom_modules.rust-filehost.enable = false;
  custom_modules.mailserver.enable = true;
}

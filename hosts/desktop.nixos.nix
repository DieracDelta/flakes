{ config, pkgs, lib, ... }:

{

  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./hw/desktop.nix ];

  custom_modules.jellyfin.enable = true;
  custom_modules.nextcloud.enable = true;
  custom_modules.core_services.enable = true;
  custom_modules.workstation_services = true;
}

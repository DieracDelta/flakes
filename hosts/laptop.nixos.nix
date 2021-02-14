{ config, pkgs, lib, ... }:
{
  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./hw/laptop.nix ];

  custom_modules.jellyfin.enable = false;
  custom_modules.nextcloud.enable = false;
  custom_modules.core_services.enable = true;
  custom_modules.workstation_services.enable = true;
}

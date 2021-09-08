{ config, pkgs, lib, ... }:

{

  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./hw/desktop.nix ];

  services.hyperspace.enable = true;
  custom_modules.jellyfin.enable = true;
  custom_modules.nextcloud.enable = true;
  custom_modules.core_services.enable = true;
  custom_modules.workstation_services.enable = true;
  custom_modules.rust-filehost.enable = false;
  custom_modules.hydra.enable = false;
  custom_modules.yubikey.enable = true;
  custom_modules.container_configs.enable = true;

}

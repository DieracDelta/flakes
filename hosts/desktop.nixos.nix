{ config, pkgs, lib, ... }:

{

  nix.settings.allowed-users = [ "jrestivo" "siraben"];
  nix.settings.trusted-users = [ "jrestivo" ];
  imports = [ ./hw/desktop.nix ];

  custom_modules.jellyfin.enable = true;
  custom_modules.nextcloud.enable = false;
  custom_modules.core_services.enable = true;
  custom_modules.workstation_services.enable = true;
  custom_modules.rust-filehost.enable = false;
  custom_modules.hydra.enable = false;
  custom_modules.yubikey.enable = true;
  custom_modules.container_configs.enable = true;
  programs.zsh.enable = true;
  programs.noisetorch.enable = true;

}

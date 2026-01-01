{
  config,
  pkgs,
  lib,
  ...
}:

{

  nix.settings.allowed-users = [
    "jrestivo"
    "siraben"
    "jachym"
    "faye"
    "john"
  ];
  nix.settings.trusted-users = [
    "jrestivo"
    "siraben"
    "jachym"
    "faye"
    "john"
  ];
  imports = [ ./hw/desktop.nix ];

  custom_modules.jellyfin.enable = true;
  custom_modules.nextcloud.enable = false;
  custom_modules.core_services.enable = true;
  custom_modules.workstation_services.enable = true;
  custom_modules.rust-filehost.enable = false;
  custom_modules.hydra.enable = true;
  custom_modules.yubikey.enable = true;
  custom_modules.container_configs.enable = false;
  custom_modules.bens_config.enable = true;
  custom_modules.network_monitor.enable = true;
  custom_modules.nethog_monitor.enable = true;
  custom_modules.monitoring.enable = true;
  custom_modules.monitoring.enableUps = true;
  custom_modules.monitoring.enableGpu = true;
  custom_modules.comfyui.enable = true;
  programs.noisetorch.enable = false;

}

# Docker configuration
# Rootless Docker with NVIDIA container toolkit
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.docker;
in
{
  options.custom_modules.docker.enable = lib.mkOption {
    description = "Enable Docker with rootless mode and NVIDIA container support";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      rootless.enable = true;
      rootless.setSocketVariable = true;
      enable = true;
      enableOnBoot = true;
    };

    hardware.nvidia-container-toolkit.enable = true;

    environment.systemPackages = with pkgs; [
      docker-compose
      oxker  # Docker TUI
      dive   # Docker image explorer
    ];
  };
}

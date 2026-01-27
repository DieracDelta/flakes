# Sunshine game streaming server
# NVIDIA CUDA-enabled remote desktop/gaming
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.sunshine;
in
{
  options.custom_modules.sunshine.enable = lib.mkOption {
    description = "Enable Sunshine game streaming server with CUDA support";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    services.sunshine = {
      package = pkgs.sunshine.override { cudaSupport = true; };
      autoStart = true;
      enable = true;
      capSysAdmin = true;
      openFirewall = true;
      settings.port = 48011;
    };

    # High priority for game streaming
    systemd.user.services.sunshine.serviceConfig = {
      Nice = -10;
      CPUWeight = 1000;
      IOSchedulingPriority = 0;
      IOWeight = 1000;
    };

    networking.firewall.allowedTCPPorts = [
      47990
      47989
    ];
  };
}

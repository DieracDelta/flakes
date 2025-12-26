{
  config,
  pkgs,
  lib,
  inputs,
  system,
  ...
}:
let
  cfg = config.custom_modules.comfyui;
in
{
  options.custom_modules.comfyui.enable = lib.mkOption {
    description = "Enable comfy ui";
    type = lib.types.bool;
    default = true;

  };
  config = lib.mkIf cfg.enable {
    services.comfyui = {
      enable = true;
      cuda = true;
      enableManager = true;
      port = 6188;
      listenAddress = "0.0.0.0";
      dataDir = "/var/lib/comfyui";
      openFirewall = true;
      # extraArgs = [ "--lowvram" ];
      # environment = { };
    };

  };

}

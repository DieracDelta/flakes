{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.ben;
in
{
  options.custom_modules.container_configs.enable = lib.mkEnableOption "Enable ben's config";
  config = lib.mkIf cfg.enable {

  };
}

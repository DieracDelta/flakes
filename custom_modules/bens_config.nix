{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.bens_config;
in
{
  options.custom_modules.bens_config.enable = lib.mkEnableOption "Enable ben's config";
  imports = [
    (fetchTarball {
      url = "https://github.com/nix-community/nixos-vscode-server/archive/2f984dfbe7e5271b5c413d3e734374cc1306c921.tar.gz";
      sha256 = "179gqv45mby7wxdmrjmk8qqfgxh9316x2l9dkcvmmqrp9i4w5qfs";
    })
  ];
  config = lib.mkIf cfg.enable {
    services.vscode-server.enable = true;

  };
}

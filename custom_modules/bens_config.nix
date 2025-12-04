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
      url = "https://github.com/nix-community/nixos-vscode-server/tarball/master";
      sha256 = "1rdn70jrg5mxmkkrpy2xk8lydmlc707sk0zb35426v1yxxka10by";
    })
  ];
  config = lib.mkIf cfg.enable {
    services.vscode-server.enable = true;

  };
}

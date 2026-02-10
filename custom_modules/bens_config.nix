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
      sha256 = "0xjal4zcbmdjdaspfkjbpx1680q7390wfzmj7iad04kp3pc9syf8";
    })
  ];
  config = lib.mkIf cfg.enable {
    services.vscode-server.enable = true;

  };
}

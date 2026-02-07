{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.trezor;
in
{
  options.custom_modules.trezor.enable = lib.mkOption {
    description = "Enable Trezor hardware wallet support.";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    # Trezor Bridge daemon + udev rules
    services.trezord.enable = true;

    # GUI app (trezorctl omitted due to CVE-2024-23342 in python-ecdsa dependency)
    environment.systemPackages = with pkgs; [
      trezor-suite # Desktop GUI app
    ];
  };
}

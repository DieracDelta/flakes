{ config, pkgs, lib, ... }:
let
  cfg = config.custom_modules.yubikey;
in
{
  options.custom_modules.yubikey.enable =
  lib.mkOption {
      description = "Enable yubikey on the machine.";
      type = lib.types.bool;
      default = false;
  };

  config = lib.mkIf cfg.enable {
    security.pam.yubico = {
      enable = true;
      debug = true;
      mode = "challenge-response";
    };

    # yubikey tools
    environment.systemPackages = with pkgs; [
      gnupg pinentry
    ];

    # expose u2f
    services.udev.packages = with pkgs; [ libu2f-host yubikey-personalization opensc pcsctools ];

    # smartcard daemon
    services.pcscd.enable = true;

  };
}

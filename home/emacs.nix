{ config, pkgs, lib, ... }:
let
  cfg = config.profiles.emacs;
in
{

  options.profiles.emacs.enable =
    lib.mkOption {
      description = "Enable custom emacs configuration.";
      type = with lib.types; bool;
      default = true;
    };

  config = lib.mkIf config.profiles.emacs.enable {
    programs.doom-emacs = {
      enable = true;
      doomPrivateDir = ./doom.d;
      emacsPackage = pkgs.emacsPgtkGcc;
    };

    services.emacs = {
      enable = true;
    };
  };
}

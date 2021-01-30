{ config, pkgs, ... }:
{
  services.emacs = {
    enable = true;
  };
  programs.doom-emacs = {
    enable = true;
    doomPrivateDir = ./doom.d;
    /*emacsPackage = pkgs.emacsGcc;*/
  };
}

{ config, pkgs, ...}:
{
  programs.emacs = {
    enable = true;
  };
  services.emacs = {
    enable = true;
  };
}

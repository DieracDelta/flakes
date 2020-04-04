{ config, pkgs, ...}:
{
  programs.emacs.enable = true;
  programs.emacs.extraPackages = epkgs: [
    epkgs.magit
    epkgs.hydra
    epkgs.evil
    epkgs.spacemacs-theme
  ];
  home.file = {
    ".emacs.d" = {
      source = ./emacs;
      recursive = true;
      onChange =  ''
        emacs --batch --eval '(byte-compile-file ".emacs.d/init.el")'
        '';
      executable = true;
    };

  };
}

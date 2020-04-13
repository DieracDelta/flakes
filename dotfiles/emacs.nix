{ config, pkgs, ...}:
{
  programs.emacs.enable = true;
  programs.emacs.package = pkgs.emacsGit;
  programs.emacs.extraPackages = epkgs: [
    epkgs.magit
    epkgs.evil-magit
    epkgs.hydra
    epkgs.evil
    epkgs.spacemacs-theme
    epkgs.ivy
    epkgs.counsel
    /* new extensions */
    epkgs.projectile
    epkgs.lsp-mode
    epkgs.rust-mode
    epkgs.git-gutter
    epkgs.lsp-ui
    epkgs.flycheck
    epkgs.company
    epkgs.company-lsp
    epkgs.lsp-treemacs
    epkgs.lsp-ivy
    epkgs.dap-mode
    epkgs.direnv
    epkgs.use-package
    epkgs.counsel-projectile
    epkgs.nix-mode
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
  services.emacs.enable = true;
}

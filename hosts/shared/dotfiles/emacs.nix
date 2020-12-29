{ config, pkgs, ...}:
{
  programs.emacs.enable = true;
  #programs.emacs.package = pkgs.emacsUnstable;
#programs.emacs.extraPackages = epkgs: [# this is the good fork
#    (epkgs.callPackage
#      ({ trivialBuild, fetchFromGitHub, lib}:
#        trivialBuild {
#          pname = "smtlib-mode";
#          ename = "smtlib-mode";
#          version = "1.0";
#          src = fetchFromGitHub {
#            owner = "LordYuuma";
#            repo = "smtlib-mode";
#            sha256 = "1p2hxazl631xfpkjys26p9p4hkl2w52r2zya530x4nq83ijdyy89";
#            rev = "46d8973e4ecbcfa39c4657ef14a54a6eacf761a5";
#          };}){})
#    (epkgs.callPackage
#      ({ trivialBuild, fetchFromGitHub, lib, pkgs }:
#        trivialBuild {
#          pname = "emacs-rust-mode";
#          ename = "emacs-rust-mode";
#          version = "1.0";
#          src = /home/jrestivo/fun/parinfer-rust-mode;
#          LD_LIBRARY_PATH="${pkgs.parinfer-rust-mode}/lib:$LD_LIBRARY_PATH";
#        }){})
#
#    epkgs.magit
#    epkgs.evil-magit
#    epkgs.hydra
#    epkgs.evil
#    epkgs.spacemacs-theme
#    epkgs.ivy
#    epkgs.counsel
#    epkgs.projectile
#    epkgs.lsp-mode
#    epkgs.rust-mode
#    epkgs.git-gutter
#    epkgs.lsp-ui
#    epkgs.flycheck
#    epkgs.company
#    epkgs.company-lsp
#    epkgs.lsp-treemacs
#    epkgs.lsp-ivy
#    epkgs.dap-mode
#    epkgs.direnv
#    epkgs.use-package
#    epkgs.counsel-projectile
#    epkgs.nix-mode
#    epkgs.tuareg
#    epkgs.merlin
#    epkgs.origami
#    epkgs.lsp-origami
#    epkgs.highlight-symbol
#    epkgs.evil-matchit
#    epkgs.smex
#    epkgs.highlight-indent-guides
#    epkgs.dumb-jump
#    epkgs.eros
#    epkgs.doom-modeline
#    epkgs.all-the-icons
#    epkgs.pretty-mode
#  ];
  #home.file = {
  #  ".emacs.d" = {
  #    source = ./emacs;
  #    recursive = true;
  #    onChange =  ''
  #      emacs --batch --eval '(byte-compile-file ".emacs.d/init.el")'
  #      '';
  #    executable = true;
  #  };
  #};
  services.emacs.enable = true;
}

{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.stateVersion = "19.09";
  programs.git.enable = true;

  programs.fzf.enableZshIntegration = true;
  imports = [ ./dotfiles/zsh.nix ./dotfiles/nvim.nix ./creds.nix ./dotfiles/emacs.nix ];

  programs.tmux.enable = true;
  programs.tmux.historyLimit = 1000000;
  programs.tmux.extraConfig = builtins.readFile ./dotfiles/tmux.conf;


  nixpkgs.overlays = [ (import ./overs)
      (import (builtins.fetchTarball {
               url = https://github.com/nix-community/emacs-overlay/archive/977a98a80df29aa94aed9e1307aadfa79eed7624.tar.gz;
               }))
  ] ;
  home.packages = [
    pkgs.rootbar pkgs.clipman pkgs.wl-clipboard pkgs.deepfry pkgs.imagemagick pkgs.wofi pkgs.zathura_rice pkgs.zlib.out pkgs.opam pkgs.m4 pkgs.nodePackages.node2nix pkgs.parinfer-rust-mode pkgs.wl-clipboard-x11
    # pkgs.next-browser-head
  ];

  manual.html.enable = true;
  # for next browser
  # environment.sessionVariables.LD_LIBRARY_PATH = [ "${pkgs.openssl.out}/lib" ];
  # environment.sessionVariables. = [ "${pkgs.openssl.out}/lib" ]
}

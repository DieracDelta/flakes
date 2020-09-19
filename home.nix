{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = { EDITOR = "nvim"; };

  home.stateVersion = "19.09";
  programs.git.enable = true;

  programs.fzf.enableZshIntegration = true;
  imports = [
    ./dotfiles/zsh.nix
    ./dotfiles/nvim.nix
    ./creds.nix
    # ./dotfiles/emacs.nix
  ];

  programs.tmux.enable = true;
  programs.tmux.historyLimit = 1000000;
  programs.tmux.extraConfig = builtins.readFile ./dotfiles/tmux.conf;

  nixpkgs.overlays = [
    (import ./overs)
    # (import (builtins.fetchTarball {
    # url = https://github.com/nix-community/emacs-overlay/archive/a28b61e511c4854fa2eccdd05877abe4d2f8fd58.tar.gz;
    # }))
    (import (builtins.fetchTarball {
      url =
        "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz";
    }))
  ];
  home.packages = [
    pkgs.rootbar
    pkgs.clipman
    pkgs.wl-clipboard
    pkgs.deepfry
    pkgs.imagemagick
    pkgs.wofi
    pkgs.zathura_rice
    pkgs.zlib.out
    pkgs.opam
    pkgs.m4
    pkgs.nodePackages.node2nix
    pkgs.parinfer-rust-mode
    pkgs.wl-clipboard-x11
    # pkgs.next-browser-head
  ];

  programs.emacs.enable = true;
  /*programs.emacs.package = pkgs.emacsGit;*/
  programs.emacs.package = pkgs.emacsUnstable;
  services.emacs.enable = true;
  manual.html.enable = true;
  # for next browser
  # environment.sessionVariables.LD_LIBRARY_PATH = [ "${pkgs.openssl.out}/lib" ];
  # environment.sessionVariables. = [ "${pkgs.openssl.out}/lib" ]
  home.file.".background-image".source = ./dotfiles/background.jpg;
  # home.file.".xmobarrc".source = ./dotfiles/xmobar.hs;

  /*xsession = {*/
    /*enable = true;*/
    /*windowManager.xmonad = {*/
      /*config = dotfiles/xmonad.hs;*/
      /*enable = true;*/
      /*enableContribAndExtras = true;*/
      /*extraPackages = haskellPackages: [*/
        /*haskellPackages.xmonad-contrib*/
        /*haskellPackages.xmobar*/
      /*];*/
    /*};*/
    /*initExtra = ''*/
      /*# Set a default pointer.*/
      /*xsetroot -cursor_name left_ptr*/

      /*# Turn off beeps.*/
      /*xset -b*/

      /*# Quicker blanking of screen.*/
      /*xset dpms 120 360 800*/
      /*dbus-launch &*/
    /*'';*/
  /*};*/

  programs.feh = { enable = true; };
}

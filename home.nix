{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = { EDITOR = "nvim"; };

  home.stateVersion = "19.09";
  programs.git.enable = true;
  programs.git.userName = "Justin Restivo";
  programs.git.userEmail = "justin.p.restivo@gmail.com";
  programs.git.extraConfig = ''
    # Enforce SSH
    [url "ssh://git@github.com/"]
      insteadOf = https://github.com/
    [url "ssh://git@gitlab.com/"]
      insteadOf = https://gitlab.com/
    [url "ssh://git@bitbucket.org/"]
      insteadOf = https://bitbucket.org/
  '';

  programs.fzf.enableZshIntegration = true;
  # imports = [ ./dotfiles/zsh.nix ./dotfiles/nvim.nix ./dotfiles/emacs.nix ];
  imports = [
    ./dotfiles/zsh.nix
    ./dotfiles/nvim.nix
    ./dotfiles/xmonad/default.nix
    ./dotfiles/emacs.nix
  ];

  programs.tmux.enable = true;
  programs.tmux.historyLimit = 1000000;
  programs.tmux.extraConfig = builtins.readFile ./dotfiles/tmux.conf;
  home.file.".wallpaper.jpg".source = ./dotfiles/wallpaper.jpg;
  home.file.".xmobarrc".source = ./dotfiles/xmonad/xmobar.hs;

  nixpkgs.overlays = [
    (import ./overs)
    #(import (builtins.fetchTarball {
    #         url = https://github.com/nix-community/emacs-overlay/archive/977a98a80df29aa94aed9e1307aadfa79eed7624.tar.gz;
    #         }))
  ];
  #home.packages = [
  #  pkgs.imagemagick
  #];

  manual.html.enable = true;
  # for next browser
  # environment.sessionVariables.LD_LIBRARY_PATH = [ "${pkgs.openssl.out}/lib" ];
  # environment.sessionVariables. = [ "${pkgs.openssl.out}/lib" ]
}

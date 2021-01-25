{ config, pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = { EDITOR = "nvim"; };

  home.stateVersion = "20.09";

  programs.git.enable = true;
  programs.git.userName = "Justin Restivo";
  programs.git.userEmail = "justin.p.restivo@gmail.com";
  programs.git.extraConfig = {
    url = { "ssh://git@github.com" = { insteadOf = "https://github.com"; }; };
    url = { "ssh://git@gitlab.com" = { insteadOf = "https://gitlab.com"; }; };
    url = {
      "ssh://git@bitbucket.org" = { insteadOf = "https://bitbucket.org"; };
    };
  };

  programs.fzf.enableZshIntegration = true;
  imports = [
    /*inputs.nix-doom-emacs.hmModule*/
    /*_module.args*/
    /*config.doom*/
    ./dotfiles/zsh.nix
    ./dotfiles/nvim.nix
    ./dotfiles/xmonad/default.nix
    ./dotfiles/emacs.nix
  ];

  # hunter config stuff
  xdg.configFile."hunter/keys".source = ./dotfiles/hunter_config;

  programs.tmux.enable = true;
  programs.tmux.historyLimit = 1000000;
  programs.tmux.extraConfig = builtins.readFile ./dotfiles/tmux.conf;

  home.file.".wallpaper.jpg".source = ./dotfiles/wallpaper.jpg;
  home.file.".xmobarrc".source = ./dotfiles/xmonad/xmobar.hs;

  #   (import ./overs)
  #(import (builtins.fetchTarball {
  #         url = https://github.com/nix-community/emacs-overlay/archive/977a98a80df29aa94aed9e1307aadfa79eed7624.tar.gz;
  #         }))
  # ];
  # home.packages = [ pkgs.deepfry pkgs.imagemagick ];

  manual.html.enable = true;
}

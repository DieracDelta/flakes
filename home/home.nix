{ config, pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = { EDITOR = "nvim"; };

  home.stateVersion = "20.09";

  programs.git = {
    enable = true;
    userName = "Justin Restivo";
    userEmail = "justin.p.restivo@gmail.com";
    extraConfig = {
      url = { "ssh://git@github.com" = { insteadOf = "https://github.com"; }; };
      url = { "ssh://git@gitlab.com" = { insteadOf = "https://gitlab.com"; }; };
      url = {
        "ssh://git@bitbucket.org" = { insteadOf = "https://bitbucket.org"; };
      };
    };
  };

  /*morally speaking should automate this in the same way im doing modules*/
  imports = [
    ./zsh.nix
    ./nvim.nix
    ./xmonad/default.nix
    ./emacs.nix
    ./home_apps.nix
  ];

  # hunter config file
  # yes... we always want hunter
  xdg.configFile."hunter/keys".source = ./hunter_config;

  programs.tmux = {
    enable = true;
    historyLimit = 1000000;
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.gruvbox;
        extraConfig = "set -g @tmux-gruvbox 'dark'";
      }
    ];
  };

  manual.html.enable = true;
}

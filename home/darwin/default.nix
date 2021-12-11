{ config, pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;

  #environment.variables = { EDITOR = "nvim"; };


  programs.git = {
    enable = true;
    userName = "Justin Restivo";
    userEmail = "justin@restivo.me";
    extraConfig = {
      github.user = "DieracDelta";
      #tag.gpgSign = true;
    };
    # TODO turn this on
    #signing.signByDefault = true;
    #signing.key = "E68281EB2ABCE9B8";
  };



  /*morally speaking should automate this in the same way im doing modules*/
  imports = [
    ../zsh.nix
  ];

  programs.tmux = {
    enable = true;
    historyLimit = 1000000;
    extraConfig = builtins.readFile ../tmux.conf;
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.gruvbox;
        extraConfig = "set -g @tmux-gruvbox 'dark'";
      }
    ];
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  xdg.configFile = with builtins; {
    "alacritty/alacritty.yml".text = builtins.readFile ../alacritty.yml;
  };


  manual.html.enable = true;
}

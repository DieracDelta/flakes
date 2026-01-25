{
  config,
  pkgs,
  inputs,
  ...
}:

{

  programs.home-manager.enable = true;

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

  home.stateVersion = "21.11";

  # morally speaking should automate this in the same way im doing modules
  imports = [
    ../fish.nix
  ];

  programs.emacs.enable = true;

  programs.tmux = {
    enable = true;
    historyLimit = 10000000;
    extraConfig = builtins.readFile ../tmux.conf;
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.gruvbox-themes;
        extraConfig = "set -g @tmux-gruvbox 'darwin'";
      }
      {
        plugin = tmuxPlugins.search-panes;
        extraConfig = "set -g @open_search_panes_key 'g'";
      }
    ];
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.atuin.enable = true;
  programs.atuin.enableFishIntegration = true;
  programs.atuin.enableZshIntegration = true;

  programs.carapace = {
    enable = true;
    enableFishIntegration = true;
  };

  manual.html.enable = true;
}

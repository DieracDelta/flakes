{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    historyLimit = 1000000;
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.gruvbox;
        extraConfig = "set -g @tmux-gruvbox 'dark'";
      }
      {
        plugin = tmuxPlugins.search-panes;
        extraConfig = "set -g @open_search_panes_key 'g'";
      }
    ];
  };
}

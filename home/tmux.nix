{ pkgs, lib, ... }:
let
  # Auto-detect theme based on platform
  # darwin = green forest theme
  # aarch64-linux = red crimson theme
  # x86_64-linux = original gruvbox
  themeName =
    if pkgs.stdenv.isDarwin then "darwin"
    else if pkgs.stdenv.hostPlatform.isAarch64 then "nixos-arm"
    else "dark";
in
{
  programs.tmux = {
    enable = true;
    historyLimit = 1000000;
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.gruvbox-themes;
        extraConfig = "set -g @tmux-gruvbox '${themeName}'";
      }
      {
        plugin = tmuxPlugins.search-panes;
        extraConfig = "set -g @open_search_panes_key 'g'";
      }
    ];
  };
}

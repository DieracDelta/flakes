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
  home.packages = [ pkgs.tmux-revive ];

  # Declarative tmux-revive runtime config (used even outside tmux plugin context)
  xdg.configFile."tmux-revive-llms/config.toml".text = ''
    codex_resume_template = "nix run \"github:sadjow/codex-nix\" -- resume {id}"
    claude_resume_template = "nix run \"github:sadjow/claude-code-nix\" -- --resume {id}"
    notify_mode = "tmux+log"
  '';

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
      {
        plugin = tmuxPlugins.revive-llms;
        extraConfig = ''
          set -g @revive-save-key 'e'
          set -g @revive-restore-key 'v'
          set -g @revive-auto-restore 'on'
          set -g @revive-auto-save-interval-minutes '15'
          set -g @revive-codex-resume-template 'nix run "github:sadjow/codex-nix" -- resume {id}'
          set -g @revive-claude-resume-template 'nix run "github:sadjow/claude-code-nix" -- --resume {id}'
          set -g @revive-notify-mode 'tmux+log'
        '';
      }
    ];
  };
}

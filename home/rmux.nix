{ pkgs, ... }:
let
  rmuxDeckBin = "/home/jrestivo/dev/rmux-deck/.worktrees/feature-rmux-impl/target/release/rmux-deck";
  rmuxDeck = pkgs.writeShellScriptBin "rmux-deck" ''
    export RMUX_DECK_RMUX_BINARY=${pkgs.rmux}/bin/rmux
    export RMUX_LIFECYCLE_LOG="''${RMUX_LIFECYCLE_LOG:-/tmp/rmux-lifecycle-$USER.log}"
    export VISP_PI_BINARY=${pkgs.pi-coding-agent}/bin/pi
    export VISP_PI_MCP_ADAPTER_PACKAGE=${pkgs.pi-mcp-adapter}/lib/node_modules/pi-mcp-adapter
    # export VISP_PI_SUBAGENTS_PACKAGE=${pkgs.pi-subagents}/lib/node_modules/@tintinweb/pi-subagents
    export VISP_PI_CODEX_GOAL_PACKAGE=${pkgs.pi-codex-goal}/lib/node_modules/pi-codex-goal
    export VISP_PI_WEB_ACCESS_PACKAGE=${pkgs.pi-web-access}/lib/node_modules/pi-web-access
    export VISP_PI_CONTEXT_MODE_PACKAGE=${pkgs.context-mode}/lib/node_modules/context-mode
    exec ${rmuxDeckBin} "$@"
  '';
in
{
  home.packages = [
    pkgs.rmux
    pkgs.pi-coding-agent
    pkgs.pi-mcp-adapter
    # pkgs.pi-subagents
    pkgs.pi-background-tasks
    pkgs.pi-codex-goal
    pkgs.pi-web-access
    pkgs.context-mode
    rmuxDeck
  ];

  xdg.configFile."rmux/rmux.conf".source = ./rmux.conf;
}

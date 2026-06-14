{ pkgs, ... }:
let
  rmuxDeckBin = "/home/jrestivo/dev/rmux-deck/.worktrees/feature-rmux-impl/target/release/rmux-deck";
  rmuxDeck = pkgs.writeShellScriptBin "rmux-deck" ''
    export RMUX_DECK_RMUX_BINARY=${pkgs.rmux}/bin/rmux
    exec ${rmuxDeckBin} "$@"
  '';
in
{
  home.packages = [
    pkgs.rmux
    rmuxDeck
  ];

  xdg.configFile."rmux/rmux.conf".source = ./rmux.conf;
}

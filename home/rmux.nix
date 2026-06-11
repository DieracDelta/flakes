{ pkgs, ... }:
{
  home.packages = [ pkgs.rmux ];

  xdg.configFile."rmux/rmux.conf".source = ./rmux.conf;
}

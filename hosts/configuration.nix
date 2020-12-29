{ config, pkgs, lib, ... }:

{

  programs.adb.enable = true;
  programs.java.enable = true;

  # TODO fix
  nixpkgs.overlays = [

    # (import (builtins.fetchTarball {
    # url = https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz;
    # sha256 = ''1zybp62zz0h077zm2zmqs2wcg3whg6jqaah9hcl1gv4x8af4zhs6'';
    # }
    # ))
    # (self: super: {
    #   discord = super.discord.overrideAttrs (_: {
    #     src = builtins.fetchTarball
    #       "https://discord.com/api/download?platform=linux&format=tar.gz";
    #   });
    # })

    # (import (builtins.fetchTarball
    #   "https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz"))

    # (self: super: {
    #   hwloc = super.hwloc.overrideAttrs (_: {
    #     x11support = true;
    #     libX11 = pkgs.xorg.libX11;
    #     cairo = pkgs.cairo;
    #   });
    # })
  ];

}

# Gaming configuration
# Steam, Heroic, gamescope, and related packages
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.gaming;
in
{
  options.custom_modules.gaming.enable = lib.mkOption {
    description = "Enable gaming support (Steam, Heroic, gamescope)";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    programs.gamescope.enable = true;
    programs.java.enable = true;

    environment.systemPackages = with pkgs; [
      heroic
      (steam.override {
        extraPkgs =
          p: with p; [
            libxcursor
            libxi
            libxinerama
            libxscrnsaver
            libpng
            libpulseaudio
            libvorbis
            stdenv.cc.cc.lib
            libkrb5
            keyutils
          ];
      })
      steamcmd
      mesa
      gnuchess
      angband
      cabextract
      gamescope
    ];
  };
}

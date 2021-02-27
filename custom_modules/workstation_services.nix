{ config, pkgs, lib, options, system, builtins, ... }:
let
  cfg = config.custom_modules.workstation_services;
  /* system */
  virtualizationPack = with pkgs; [
    virt-manager
    looking-glass-client
    qemu
    OVMF
    libvirt
  ];
  /* system */
  gamingPack = with pkgs; [
    wine
    cowsay
    steam
    mesa
    gnuchess
    angband
    winetricks
    protontricks
    cabextract
    m4
  ];
  xPack = with pkgs; [
    redshift
    xorg.xwininfo
    brightnessctl
    imagemagick
    deepfry
    arandr
    playerctl
    gtk3
    shared_mime_info
    maim
    xclip
    xmobar
    libGL
    libGLU
    glxinfo
  ];
in
{
  options.custom_modules.workstation_services.enable =
    lib.mkOption {
      description = ''
        Extraneous services to be enabled only when X server is used (e.g. not on servers).
      '';
      type = lib.types.bool;
      default = false;
    };

  config = lib.mkIf cfg.enable {
    # weird bug. Need this in order to get xmonad to work in home-manager.
    services.xserver = {
      enable = true;
      layout = "us";
      displayManager = { lightdm.enable = true; };
      windowManager.i3 = {
        enable = true;
        package = pkgs.i3-gaps;
        extraPackages = with pkgs; [ rofi ];
      };
      libinput.enable = true;

    };
    services.xrdp.enable = true;
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
      #enableNvidia = true;
      enableOnBoot = true;
    };

    boot.plymouth = {
      /*TODO add in custom boot icons*/
      enable = true;
      /*logo = ''*/
      /*pkgs.fetchurl {*/
      /*url = "https://nixos.org/logo/nixos-hires.png";*/
      /*sha256 = "1ivzgd7iz0i06y36p8m5w48fd8pjqwxhdaavc0pxs7w1g7mcy5si";*/
      /*}'';*/
    };
    /*TODO add in configuration option for this (like embedded dev enable)*/
    programs.adb.enable = true;
    programs.java.enable = true;
    environment.systemPackages =
      builtins.concatLists [
        gamingPack
        xPack
      ];

    fonts.fonts = with pkgs;
      [
        d2coding
        iosevka
        aileron
        nerdfonts
        fira-code
        fira-code-symbols
        fira-mono
      ];
  };

}

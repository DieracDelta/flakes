{ profiles, config, pkgs, lib, ... }:
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

  environment.systemPackages =
    builtins.concatLists [
      gamingPack
      xPack
    ];

  fonts.fonts = with pkgs; [
    d2coding
    iosevka
    aileron
    nerdfonts
    fira-code
    fira-code-symbols
    fira-mono
  ];
}

{ config, pkgs, lib, options, system, builtins, ... }:
let
  cfg = config.custom_modules.workstation_services;
  /* system */
  virtualizationPack = with pkgs; [
    lutris
    docker-compose
    virt-manager
    looking-glass-client
    cdrkit
    qemu
    OVMF
    libvirt
    ghc
    cabal-install
    # stack
    #firefox
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
    syncthing
    gnome.cheese
    kdeconnect
    trezor-suite
    redshift
    xorg.xwininfo
    brightnessctl
    imagemagick
    deepfry
    arandr
    playerctl
    gtk3
    shared-mime-info
    maim
    xclip
    xmobar
    libGL
    libGLU
    glxinfo
    obsidian
  ];
  yubikeyPack = with pkgs; [
    gnupg pinentry-curses pinentry-qt paperkey wget rng-tools
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
    # virtualisation.docker = {
    #   enable = true;
    #   autoPrune.enable = true;
    #   #enableNvidia = true;
    #   enableOnBoot = true;
    # };

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
        yubikeyPack
        gamingPack
        xPack
        virtualizationPack
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
    services.picom.enable = true;
    services.syncthing.enable = true;
    networking.firewall.allowedTCPPorts = [ 22000 8384 ];
    programs.dconf.enable = true;

    #services.atd.enable = true;

    #services.udev.packages = [ pkgs.yubikey-personalization ];
    #environment.shellInit = ''
    #  export GPG_TTY="$(tty)"
    #  gpg-connect-agent /bye
    #  export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"
    #'';
    #programs.ssh.startAgent = false;
    #programs.gnupg.agent = {
    #  enable = true;
    #  enableSSHSupport = true;
    #};
  };

}

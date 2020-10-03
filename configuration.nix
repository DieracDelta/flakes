# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      discord = super.discord.overrideAttrs (_: {
        src = builtins.fetchTarball
          "https://discord.com/api/download?platform=linux&format=tar.gz";
      });
    })

    (import (builtins.fetchTarball
      "https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz"))
  ];

  hardware.cpu.intel.updateMicrocode = true;

  # services.xserver.videoDrivers = [ "modesetting" "nvidia" ];
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.optimus_prime = {
    enable = true;

    # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
    nvidiaBusId = "PCI:1:0:0";

    # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA
    intelBusId = "PCI:0:2:0";
  };

  imports = [ # Include the results of the hardware scan.
    /etc/nixos/hardware-configuration.nix
    ./dotfiles/docker.nix
    ./block_hosts/hosts.nix
  ];
  hardware.bluetooth.enable = true;

  virtualisation.docker.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = let
    textPack = with pkgs; [
      gimp
      tdesktop
      nixfmt
      clang-tools
      neovim
      evtest
      evemu
      opam
    ];
    wlPack = with pkgs; [
      emacs
      flameshot
      wev
      swaylock
      gtk3
      xdg_utils
      shared_mime_info
      wf-recorder
      slurp
      grim
      unzip
    ];
    xPack = with pkgs; [ maim xclip xmobar libGL libGLU glxinfo ];
    cliPack = with pkgs; [
      fzf
      zsh
      oh-my-zsh
      ripgrep
      neofetch
      tmux
      playerctl
      fasd
      jq
      haskellPackages.cryptohash-sha256
      mosh
      pstree
      tree
      ranger
      nix-index
      mpv
      youtube-dl
      file
      fd
      sd
      tealdeer
      htop
      wget
      ispell
    ];
    devPack = with pkgs; [
      cask
      nodejs
      git
      universal-ctags
      qemu
      virt-manager
      libvirt
      OVMF
      looking-glass-client
      nasm
      lua
      idea.idea-community
      gdb
      direnv
    ];
    utilsPack = with pkgs; [
      binutils
      gcc
      gnumake
      openssl
      pkgconfig
      ytop
      pciutils
      usbutils
      lm_sensors
      liblqr1
      zlib.dev
    ];
    toolPack = with pkgs; [ pavucontrol keepass pywal pithos ];
    gamingPack = with pkgs; [
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
    # deploymentPack = with pkgs; [hugo];
    # bapPack = with pkgs; [ libbap skopeo python27 m4];
    appPack = with pkgs; [
      xorg.xwininfo
      riot-desktop
      pipenv
      latest.firefox-nightly-bin
      discord
      zathura
      mumble
      feh
      mplayer
      slack
      weechat
      llvm
      gmp.static.dev
      skypeforlinux
      spotify
      browsh
      keybase
      keybase-gui
      kbfs
      obs-studio
      graphviz
      minecraft
      signal-desktop
      opencv
      alacritty
      keepass
      mimic
      zoom-us
      opencv
    ];
    hackPack = with pkgs; [ ghidra-bin john ];
    python37Pack = with pkgs;
      let
        my-python-packages = python-packages:
          with python-packages; [
            pywal
            jedi
            flake8
            pep8
            tesserocr
            pillow
            autopep8
            xdot
            opencv4
            numpy
          ];
        python-with-my-packages = python37.withPackages my-python-packages;
      in [ python-with-my-packages ];

  in builtins.concatLists [
    textPack
    wlPack
    cliPack
    devPack
    toolPack
    utilsPack
    appPack
    gamingPack
    python37Pack
    hackPack
    xPack
  ];

  environment.etc = { };

  environment.variables = {
    BROWSER = "firefox";
    EDITOR = "nvim";
  };

  services.gnome3.gnome-keyring.enable = true;
  nix.allowedUsers = [ "jrestivo" ];

  # steam shit
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  location.provider = "geoclue2";

  # TODO to get working exwm, uncomment this
  # services.xserver = {
  #   enable = true;
  #   layout = "us";
  #   libinput = {
  #     enable = true;
  #   };
  # displayManager.sessionCommands = "${pkgs.xorg.xhost}/bin/xorg +SI:localhost:$USER";
  # };

  # TODO to get working exwm, uncomment this
  # services.xserver.windowManager.session = lib.singleton {
  #         name = "exwm";
  #         start = ''
  #           ${pkgs.emacs}/bin/emacs --daemon -f exwm-enable
  #           ${pkgs.emacs}/bin/emacsclient -c
  #         '';
  # };

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

  users.users.jrestivo = {
    isNormalUser = true;
    home = "/home/jrestivo";
    shell = pkgs.zsh;
    description = "Justin --the owner-- Restivo";
    extraGroups = [ "wheel" "networkmanager" "audio" "input" "docker" ];
  };

  fonts.fonts = with pkgs; [
    d2coding
    iosevka
    aileron
    nerdfonts
    fira-code
    fira-code-symbols
    fira-mono
  ];

  networking.hostName = "nixos"; # Define your hostname.

  networking.useDHCP = false;
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  services.openssh.enable = true;
  services.openssh.authorizedKeysFiles =
    [ "/home/jrestivo/.config/authorized_users" ];
  services.openssh.passwordAuthentication = false;

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;
  nixpkgs.config.allowUnfree = true;

  services.lorri.enable = true;

  programs.mosh.enable = true;
}


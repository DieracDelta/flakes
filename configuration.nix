# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{

  imports = [ # Include the results of the hardware scan.
    /etc/nixos/hardware-configuration.nix
    ./dotfiles/docker.nix
    ./dotfiles/wayland/sway_service.nix
    /*./block_hosts/hosts.nix*/
    # ./dotfiles/emacs.nix
    # ./dotfiles/gpu_passthrough.nix
  ];

  virtualisation.docker.enable = true;
  /*users.extraGroups.vboxusers.members = [ "jrestivo" ];*/
  /*virtualisation.virtualbox.host.enable = true;*/
  /*virtualisation.virtualbox.host.enableExtensionPack = true;*/

  programs.adb.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.overlays = [
    # (import (builtins.fetchTarball {
    # url = https://github.com/nixos-rocm/nixos-rocm/archive/master.tar.gz;
    # }))
    (import (builtins.fetchTarball {
      url = "https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz";
    }))
    (self: super: {
      discord = super.discord.overrideAttrs (_: {
        src = builtins.fetchTarball
          "https://discord.com/api/download?platform=linux&format=tar.gz";
      });
    })
  ];

  environment.systemPackages = let
    textPack = with pkgs; [ neovim ];
    rustPack = with pkgs; [ dust hyperfine sd ];
    wlPack = with pkgs; [
      wdisplays
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
    xPack = with pkgs; [ rofi xmobar leptonica];
    cliPack = with pkgs; [
      perl
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
      coq
      # pkgs.texlive.combined.scheme-full
      # texlab
      # tectonic
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
    haskellPack = with pkgs; [
      stack
      haskellPackages.ghcide
      stack
      cabal-install
      haskellPackages.hlint
      haskellPackages.ghc
      haskellPackages.xmonad-contrib
      haskellPackages.xmobar
    ];
    utilsPack = with pkgs; [
      tesseract4
      nixfmt
      gtk2-x11.dev
      pcre
      parallel
      sshpass
      gnutls
      binutils
      lshw
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
      pandoc
    ];
    toolPack = with pkgs; [ pavucontrol keepass pywal pithos ];
    gamingPack = with pkgs; [
      anbox
      genymotion
      cowsay
      steam
      vulkan-loader
      vulkan-tools
      mesa
      gnuchess
      angband
      winetricks
      protontricks
      cabextract
    ];
    # to set firefox as default instead of chrome: xdg-mime default firefox.desktop x-scheme-handler/https x-scheme-handler/http
    appPack = with pkgs; [
      tdesktop
      spotify
      radeontop
      chromium
      gnome3.cheese
      lynx
      zip
      xxd
      gist
      libreoffice
      # lutris
      geoclue2
      redshift
      tigervnc
      telnet
      inkscape
      okular
      # discord-canary
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
      latest.firefox-nightly-bin
      keybase
      keybase-gui
      kbfs
      qutebrowser
      obs-studio
      graphviz
      minecraft
      signal-desktop
      alacritty
      keepass
      mimic
      zoom-us
      mattermost
    ];
    # TODO add in hunter
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
            numpy
            matplotlib
            pytesseract
            opencv4
          ];
        python-with-my-packages = python37.withPackages my-python-packages;
      in [ python-with-my-packages ];

  in builtins.concatLists [
    rustPack
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
    haskellPack
    xPack
  ];

  environment.etc = {
    "sway/config".source = ./dotfiles/wayland/sway_config;
    "rootbar/rootbar_config".source = ./dotfiles/wayland/rootbar/rootbar_config;
    "rootbar/rootbar.css".source = ./dotfiles/wayland/rootbar/rootbar.css;
    "wofi/style.css".source = ./dotfiles/wayland/wofi/wofi_style.css;
    "wofi/config".source = ./dotfiles/wayland/wofi/wofi_config;
    "wofi/wofi_parse.sh".source = ./dotfiles/wayland/wofi/wofi_parse.sh;
    "rootbar/handler_script.lua".source =
      ./dotfiles/wayland/rootbar/handler_script.lua;
    "rootbar/handler_script.lua".mode = "0666";
  };

  environment.variables = {
    BROWSER = "firefox";
    EDITOR = "nvim";
  };

  services.gnome3.gnome-keyring.enable = true;

  /*services.xserver.displayManager.startx.enable = true;*/
  # xmonad / taffybar dependencies
  /*services.xserver = {*/
    /*enable = true;*/
    /*layout = "us";*/
    /*libinput.enable = true;*/
  /*};*/
  /*services.xserver.desktopManager.session = [{*/
    /*name = "home-manager";*/
    /*start = ''*/
      /*${pkgs.runtimeShell} $HOME/.hm-xsession &*/
      /*waitPID=$!*/
    /*'';*/
  /*}];*/

  services.xserver.desktopManager.xterm.enable = true;

  services.upower.enable = true;
  systemd.services.upower.enable = true;

  # TODO comment this out if things break
  # services.xserver = {
  # enable = true;

  # desktopManager = {
  # default = "none+i3";
  # xterm.enable = true;
  # };

  # windowManager.i3 = {
  # enable = true;
  # extraPackages = with pkgs; [
  # dmenu #application launcher most people use
  # ];
  # };
  # };
  # TODO comment this out if things break

  nix.allowedUsers = [ "jrestivo" ];

  # steam shit
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  # bluetooth
  hardware.bluetooth.enable = true;

  location.provider = "geoclue2";

  users.users.jrestivo = {
    isNormalUser = true;
    home = "/home/jrestivo";
    shell = pkgs.zsh;
    description = "Justin --big brain-- Restivo";
    extraGroups = [ "wheel" "networkmanager" "sway" "audio" "input" "docker" "adbusers" ];
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

  services.openssh.forwardX11 = true;
  services.openssh.enable = true;
  services.openssh.authorizedKeysFiles =
    [ "/home/jrestivo/.config/authorized_users" ];
  services.openssh.passwordAuthentication = false;

  sound.enable = true;
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [ libGL ];
    setLdLibraryPath = true;
  };

  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
  };
  nixpkgs.config.pulseaudio = true;
  nixpkgs.config.allowUnfree = true;

  services.lorri.enable = true;

  system.stateVersion = "19.09"; # Did you read the comment? No I did not.

  programs.mosh.enable = true;


  xdg.mime.enable = true;
  services.xserver = {
    enable = true;
    layout = "us";
    displayManager.lightdm = {
      enable = true;
    };
    libinput.enable = true;
    windowManager.i3 = {
      enable = true;
      configFile = ./dotfiles/wayland/sway_config;
      extraPackages = [pkgs.i3lock];
      extraSessionCommands = "systemd  --user restart autostart.target";
      package = pkgs.i3;
    };
  };



}


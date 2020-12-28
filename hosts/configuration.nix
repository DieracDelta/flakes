# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  # nix = {
  #   package = pkgs.nixUnstable;
  #   extraOptions = ''
  #     experimental-features = nix-command flakes
  #   '';
  # };

  users.users.jrestivo.openssh.authorizedKeys.keys = [''
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnVsxxx7yiI1yWh2+wkmH7jMDTfvypsLfVkYuz+WObIi3V+1gZN3cPjHFYwEa1SpUNSs4/c2zdM1CANR5b61YgBmvbxYUVCBFNSeO1B9JTPUDcyM20vhRdeUOFlPS0KJHkKnlzjq4sEnjDM+zXCtAKEekBRcWqcnK2WX/Q9CI6+ocaJ30r06T0Hqa4C7Gx6pNbVNxaTaza3Mzod68aBjyg7WShsKPF5nLSe9QJIjUQ2bjGdRCUlXshgmW+E127KqryZqYLmmodF9fynCK6Ne+MDM2jEruRHMwhv50MfnO0ntOOM0i37oR3JuKE+AzJj/+Ete/YVbbIxipMm0DkNJEEqFsZRO5qkiP2MpI4TCZxHaac/pl+W6HdhwzSKCUrVBUTwEacaz/3WFgGgTjebpW1hfYbcTalG6e9t2W0OSg+INYLklp4uHDWHjFqyl5J+FZMNQdtWgD3yRyZN9rf1ojVf5AgxSW6pXIcrqMf/6Kf+kr/O0FOakrLaEHTDmONVTM= justin.p.restivo@gmail.com
  ''];
  programs.adb.enable = true;
  programs.java.enable = true;

  # TODO fix
  nixos.overlays = [

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

    (self: super: {
      hwloc = super.hwloc.overrideAttrs (_: {
        x11support = true;
        libX11 = pkgs.xorg.libX11;
        cairo = pkgs.cairo;
      });
    })
  ];

  hardware.cpu.intel.updateMicrocode = true;

  # services.xserver.videoDrivers = [ "modesetting" "nvidia" ];
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.prime = {
    sync.enable = true;

    # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
    nvidiaBusId = "PCI:1:0:0";

    # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA
    intelBusId = "PCI:0:2:0";
  };

  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./docker.nix
    # ./block_hosts/hosts.nix
  ];
  hardware.bluetooth.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    enableNvidia = true;
    enableOnBoot = true;
  };

  # virtualisation.virtualbox.host.enable = true;
  # users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];

  boot.loader.systemd-boot.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  services.zerotierone.enable = true; # Default value is 'false'
  services.zerotierone.joinNetworks =
    [ "af415e486feddf70" ]; # Default value is '[]'

  environment.systemPackages =

    let
      textPack = with pkgs; [
        flameshot

        (haskellPackages.ghcWithPackages
          (pkgs: [ pkgs.sort pkgs.base pkgs.split pkgs.lens ]))
        haskellPackages.hoogle
        haskellPackages.hlint
        haskellPackages.brittany
        # cabal
        # haskellPackages.Data
        haskellPackages.ghcide
        dante

        tigervnc
        (texlive.combine {
          inherit (texlive) scheme-medium lipsum fmtcount datetime;
        })
        cargo
        rustup
        rustc
        # rustChannels.stable.rust
        hwloc
        ngrok
        nixos-generators
        vscode
        wine
        pdftk
        vimb
        # libreoffice
        redshift
        brightnessctl
        arandr
        zoom
        uutils-coreutils
        nix-tree
        android-studio
        # cudnn
        # cudaPackages.cudatoolkit_10_2
        # cudaPackages.cudatoolkit_11
        nixFlakes
        gimp
        tdesktop
        nixfmt
        clang-tools
        neovim
        evtest
        cmake
        evemu
        opam
        opencl-headers
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
        clang
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
        element-desktop
        pipenv
        # latest.firefox-nightly-bin
        firefox
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
        alacritty
        keepass
        mimic
        zoom-us
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
    extraGroups =
      [ "wheel" "networkmanager" "audio" "input" "docker" "adbusers" ];
  };

  fonts.fonts = with pkgs; [
    d2coding
    iosevka
    aileron
    # nerdfonts
    fira-code
    fira-code-symbols
    fira-mono
  ];

  networking.hostName = "nixos"; # Define your hostname.

  networking.useDHCP = false;
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  services.openssh.enable = true;
  # services.openssh.authorizedKeysFiles =
  # [ "/home/jrestivo/.config/authorized_users" ];
  services.openssh.passwordAuthentication = false;

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixos.config.pulseaudio = true;
  nixos.config.allowUnfree = true;

  services.lorri.enable = true;

  system.stateVersion = "20.09";
  programs.mosh.enable = true;

}

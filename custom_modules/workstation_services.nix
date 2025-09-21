{
  config,
  pkgs,
  lib,
  options,
  system,
  builtins,
  nixpkgs-stable,
  nixpkgs-master,
  ...
}:
let
  tmpnixpkgs = import nixpkgs-master {
    inherit system;
    config = {
      allowUnfree = true;
    };
  };
  cfg = config.custom_modules.workstation_services;
  # system
  virtualizationPack = with pkgs; [
    eternal-terminal
    nix
    spider
    # lutris
    yq
    spicetify-cli
    # wine
    heroic
    croc
    # qt5.wrapQtAppsHook
    # libsForQt5.qt5.qtconnectivity
    sqlite
    # libsForQt5.qt5.qtgui
    # libsForQt5.qt5.qtgamepad
    # libsForQt5.qt5.qtgraphicaleffects
    # libsForQt5.qt5.qtlocation
    # libsForQt5.qt5.qtquickcontrols2
    # libsForQt5.qt5.qtserialport

    # xboxdrv
    docker-compose
    smartmontools
    oxker # docker shit
    magic-wormhole-rs # file transfer
    spotdl
    kitty
    vorbis-tools
    fio
    # virt-manager
    # looking-glass-client
    cdrkit
    qemu
    OVMF
    elfx86exts
    magic-wormhole
    gitoxide
    pax-utils
    fselect
    kmon
    # chromium
    # libvirt
    # ghc
    # cabal-install
    # stack
    #firefox
  ];
  # system
  gamingPack = with pkgs; [
    # rustdesk
    nix-output-monitor
    # nix-janitor
    # ollama
    xbanish
    cudaPackages.cudatoolkit
    # cudaPackages.cudnn_8_9
    # wine
    # winetricks
    # protontricks
    cowsay
    kdePackages.wacomtablet
    (steam.override {
      extraPkgs =
        p: with p; [
          xorg.libXcursor
          xorg.libXi
          xorg.libXinerama
          xorg.libXScrnSaver
          libpng
          libpulseaudio
          libvorbis
          stdenv.cc.cc.lib
          libkrb5
          keyutils

        ];
    })
    steamcmd
    # steam-run
    mesa
    gnuchess
    angband
    cabextract
    m4
  ];
  xPack = with pkgs; [
    tdf
    libimobiledevice
    ifuse
    # kdePackages.kdeconnect-kde
    yazi
    ghostty
    # cachix
    discord
    noisetorch
    syncthing
    # gnome.cheese
    # kdeconnect
    # trezor-suite
    redshift
    xorg.xwininfo
    brightnessctl
    imagemagick
    #deepfry
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
    # obsidian
  ];
  yubikeyPack = with pkgs; [
    lsr
    zig
    gnupg
    pinentry-curses
    # pinentry-qt
    paperkey
    wget
    rng-tools
    clinfo
    vulkan-loader # vulkan-volk
    vulkan-tools
    vulkan-utility-libraries
    vulkan-validation-layers
    vulkan-helper
    vulkan-headers
    vulkan-caps-viewer
    vulkan-extension-layer
    vk-bootstrap
    amdvlk
    vkmark
    vkdisplayinfo
    vk-bootstrap
    gpu-viewer
    cntr
  ];
in
{
  options.custom_modules.workstation_services.enable = lib.mkOption {
    description = ''
      Extraneous services to be enabled only when X server is used (e.g. not on servers).
    '';
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;
    services.libinput.enable = true;
    services.displayManager.sddm.enable = true;
    # weird bug. Need this in order to get xmonad to work in home-manager.
    services.xserver = {
      enable = true;
      xkb.layout = "us";
      # displayManager = { lightdm.enable = true; };
      windowManager.i3 = {
        enable = true;
        package = pkgs.i3-gaps;
        extraPackages = with pkgs; [ rofi ];
      };

      # desktopManager.gnome.enable = true;
      # .gdm.enable = true;
      # desktopManager.gnome.enable = true;
      # displayManager.gdm.enable = true;
      # windowManager.bspwm.enable = true;
    };

    # services.rustdesk-server.enable = true;
    # services.rustdesk-server.openFirewall = true;
    # services.rustdesk-server.relayIP = "100.74.54.40";

    # programs.ssh.askPassword = lib.mkForce "${pkgs.plasma5Packages.ksshaskpass}/bin/ksshaskpass";

    services.xrdp.enable = true;
    virtualisation.docker = {
      rootless.enable = true;

      rootless.setSocketVariable = true;
      enable = true;
      # autoPrune.enable = true;
      enableOnBoot = true;
    };
    hardware.nvidia-container-toolkit.enable = true;

    boot.plymouth = {
      # TODO add in custom boot icons
      enable = true;
      # logo = ''
      # pkgs.fetchurl {
      # url = "https://nixos.org/logo/nixos-hires.png";
      # sha256 = "1ivzgd7iz0i06y36p8m5w48fd8pjqwxhdaavc0pxs7w1g7mcy5si";
      # }'';
    };
    # TODO add in configuration option for this (like embedded dev enable)
    programs.adb.enable = true;
    programs.java.enable = true;
    programs.steam.enable = true;
    programs.steam.remotePlay.openFirewall = true;
    programs.steam.dedicatedServer.openFirewall = true;

    environment.systemPackages = builtins.concatLists [
      yubikeyPack
      gamingPack
      xPack
      virtualizationPack
    ];

    fonts.packages = with pkgs; [
      d2coding
      # iosevka
      aileron
      nerd-fonts.fira-code
      fira-code
      fira-code-symbols
      fira-mono
    ];

    services.picom.enable = true;
    services.syncthing.enable = true;
    networking.firewall.allowedTCPPorts = [
      8081
      22000
      8384
      8080
      2022
      8188
      11434
    ];
    # networking.firewall = {
    #   enable = true;
    #   allowedTCPPortRanges = [
    #     { from = 1714; to = 1764; } # KDE Connect
    #   ];
    #   allowedUDPPortRanges = [
    #     { from = 1714; to = 1764; } # KDE Connect
    #   ];
    # };
    programs.dconf.enable = true;
    systemd.user.services.atuind = {
      enable = true;

      environment = {
        ATUIN_LOG = "warn";
      };
      serviceConfig = {
        ExecStart = "${pkgs.atuin}/bin/atuin daemon";
      };
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
    };
    #
    services.atuin = {
      openRegistration = true;
      enable = true;
      host = "0.0.0.0";
      port = 4200;
      openFirewall = true;
      maxHistoryLength = 10000000;
    };

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
    services.searx = {
      enable = true;
      redisCreateLocally = true;
      settings.server = {
        bind_address = "0.0.0.0";
        port = "3838";
        secret_key = "secret key";
      };
      settings.search = {
        formats = [
          "html"
          "json"
        ];
      };

    };

    # services.comfyui = {
    #   enable = true;
    #   home = "/var/lib/comfyui";
    #   acceleration = "cuda";
    #   host = "0.0.0.0";
    #   openFirewall = true;
    #   # withModels = [
    #   #   pkgs.fetchResource
    #   #   {
    #   #     url = "https://civitai.com/api/download/models/1026423?type=Model&format=SafeTensor";
    #   #     sha256 = "B1C4DDF95671E6B51817B4F3802865E544040C232C467E76B1CB0C251BD6B634";
    #   #     passthru = {
    #   #       comfyui.installPaths = [ "loras" ];
    #   #     };
    #   #   }
    #   # ];
    # };

    services.ollama = {
      package = tmpnixpkgs.ollama;
      #package = (import nixpkgs-stable { system = "x86_64-linux"; config.allowUnfree = true; }).ollama;
      loadModels = [
        "deepseek-r1:32b"
        "deepseek-r1:14b"
        "SIGJNF/deepseek-r1-671b-1.58bit"
      ];
      enable = true;
      acceleration = "cuda";
      host = "0.0.0.0";
      # environmentVariables = {"OLLAMA_KV_CACHE_TYPE" = "q4_0"; };
    };
    services.open-webui = {
      package = tmpnixpkgs.open-webui;
      openFirewall = true;
      enable = true;
      host = "0.0.0.0";
      environment = {
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        # Disable authentication
        WEBUI_AUTH = "False";
      };
    };

    services.sunshine = {
      package = pkgs.sunshine.override { cudaSupport = true; };
      autoStart = true;
      enable = true;
      capSysAdmin = true;
      openFirewall = true;
    };

    # programs.kdeconnect.enable = true;

    services.usbmuxd = {
      enable = true;
      package = pkgs.usbmuxd2;
    };

    security.sudo-rs.enable = true;
    services.eternal-terminal.enable = true;

  };

}

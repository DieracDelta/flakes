# Workstation services
# Meta-module that enables desktop workstation functionality
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
  cfg = config.custom_modules.workstation_services;
in
{
  options.custom_modules.workstation_services.enable = lib.mkOption {
    description = ''
      Enable workstation services (desktop environment, gaming, AI, etc.)
      This is a meta-module that enables various sub-modules.
    '';
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    # Enable sub-modules
    custom_modules.desktop.enable = true;
    custom_modules.docker.enable = true;
    custom_modules.gaming.enable = true;
    custom_modules.ollama.enable = true;
    custom_modules.sunshine.enable = true;
    custom_modules.homepage.enable = true;

    # Disable system sleep/suspend - this is a desktop running services
    systemd.targets.sleep.enable = false;
    systemd.targets.suspend.enable = false;
    systemd.targets.hibernate.enable = false;
    systemd.targets.hybrid-sleep.enable = false;

    services.logind.settings.Login = {
      IdleAction = "ignore";
      IdleActionSec = 0;
    };

    # Syncthing
    services.syncthing.enable = true;

    # Atuin shell history sync
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

    services.atuin = {
      openRegistration = true;
      enable = true;
      host = "0.0.0.0";
      port = 4200;
      openFirewall = true;
      maxHistoryLength = 10000000;
    };

    # SearX private search
    services.searx = {
      enable = true;
      redisCreateLocally = true;
      settings.server = {
        base_url = "https://office-desktop.tail5ca7.ts.net/searx";
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

    # Scrutiny disk health monitoring
    services.scrutiny.enable = true;
    services.scrutiny.collector.enable = true;
    services.scrutiny.settings.web.listen.port = 5123;
    services.scrutiny.openFirewall = true;
    services.scrutiny.settings.web.listen.basepath = "/scrutiny";
    services.scrutiny.collector.settings.devices = [
      {
        device = "/dev/sda";
        type = "sat";
      }
      {
        device = "/dev/sdc";
        type = "sat";
      }
      {
        device = "/dev/nvme0";
        type = "nvme";
      }
      {
        device = "/dev/nvme1";
        type = "nvme";
      }
    ];

    # Netdata monitoring
    services.netdata = {
      package = pkgs.netdata.override { withCloudUi = true; };
      enable = true;
      config.global = {
        "memory mode" = "ram";
        "debug log" = "none";
        "access log" = "none";
        "error log" = "syslog";
      };
    };

    # Glances monitoring
    services.glances = {
      enable = true;
      openFirewall = true;
      port = 5124;
    };

    # Eternal Terminal priority
    services.eternal-terminal = {
      enable = true;
      port = 2022;
    };

    systemd.services.eternal-terminal.serviceConfig = {
      IPEgressPriority = 1;
      IPIngressPriority = 1;
      Nice = -10;
      CPUWeight = 1000;
      IOSchedulingPriority = 0;
      IOWeight = 1000;
    };

    # Lower priority for nix-daemon during builds + memory limits
    systemd.services.nix-daemon.serviceConfig = {
      Nice = lib.mkForce 15;
      IOSchedulingClass = lib.mkForce "idle";
      IOSchedulingPriority = lib.mkForce 7;
      IPEgressPriority = 7;
      IPIngressPriority = 7;
      MemoryHigh = "80G"; # Soft limit - throttles allocations when exceeded
      MemoryMax = "100G"; # Hard limit - OOM killer if exceeded
    };

    # USB multiplexer for iOS devices
    services.usbmuxd = {
      enable = true;
      package = pkgs.usbmuxd2;
    };

    # PAM insults for failed sudo
    security.pam.services.sudo.rules.auth.insults = {
      order = 12300;
      control = "optional";
      modulePath = "${pkgs.pam-insults}/lib/security/pam_insults.so";
      args = [ "type=unhinged" ];
    };

    security.pam.services.sudo.rules.auth.skip-insults-siraben = {
      order = 12299;
      control = "[success=1 default=ignore]";
      modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
      args = [
        "user"
        "="
        "siraben"
      ];
    };

    # Journal retention
    services.journald.extraConfig = ''
      SystemMaxUse=500G
      MaxRetentionSec=6month
      MaxFileSec=1week
    '';

    # Firewall ports
    networking.firewall.allowedTCPPorts = [
      3428
      8081
      22000
      8384
      8080
      2022
      8188
    ];

    # Flattened system packages (no fake categories)
    environment.systemPackages = with pkgs; [
      # CLI tools
      poppler-utils
      eternal-terminal
      nix
      nix-prefetch-docker
      nix-prefetch-github
      nix-prefetch-pijul
      nix-prefetch-scripts
      nix-prefetch
      yq
      croc
      nixpkgs-hammering
      nix-eval-jobs
      nix-diff
      scrutiny
      scrutiny-collector
      ethtool
      sqlite
      difftastic
      cachix
      nix-btm
      nix-search
      smartmontools
      magic-wormhole-rs
      vorbis-tools
      fio
      bandwhich
      binsider
      dua
      fzf-make
      trippy
      elfx86exts
      magic-wormhole
      gitoxide
      pax-utils
      fselect
      kmon

      # AI/LLM tools
      claude-code
      claude-chill
      opencode
      lmstudio
      gemini-cli
      goose-cli
      bingrep
      qwen-code

      # Multimedia
      streamrip
      gnupg
      uv
      python3

      # System tools
      partclone
      crush
      pam-insults
      btop
      nethogs
      qemu
      OVMF
      cdrkit

      # GUI apps
      asciinema
      tdf
      libimobiledevice
      ifuse
      yazi
      ghostty
      kitty
      discord
      noisetorch
      syncthing
      redshift
      xorg.xwininfo
      brightnessctl
      imagemagick
      arandr
      playerctl
      gtk3
      shared-mime-info
      maim
      xclip
      xmobar
      libGL
      libGLU
      nix-output-monitor
      xbanish
      cudaPackages.cudatoolkit
      cowsay
      kdePackages.wacomtablet
      m4

      # Vulkan/GPU tools
      # lsr  # broken upstream: postConfigure→postPatch bug in nixpkgs master
      zig
      gnupg
      paperkey
      wget
      rng-tools
      clinfo
      vulkan-loader
      powertop
      vulkan-tools
      vulkan-utility-libraries
      vulkan-validation-layers
      id3v2
      vulkan-helper
      vulkan-headers
      vulkan-caps-viewer
      vulkan-extension-layer
      vk-bootstrap
      vkdisplayinfo
      gpu-viewer
      cntr
      rainfrog
      oxker
    ];
  };
}

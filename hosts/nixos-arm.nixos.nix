# ARM OCI instance configuration
# Oracle Cloud aarch64 instance with LVM/btrfs storage
{ pkgs, lib, ... }:
{
  imports = [
    ./hw/oci_arm.nix
  ];

  system.stateVersion = "25.11";

  # Disable documentation to reduce closure size
  documentation.enable = false;

  # Enable LVM support for ~195GB combined storage (boot partition 3 + block volume)
  oci.hardware.enableLVM = true;

  # Mount /nix and /home from LVM btrfs volume
  fileSystems."/nix" = {
    device = "/dev/datavg/datalv";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd"
      "noatime"
    ];
  };
  fileSystems."/home" = {
    device = "/dev/datavg/datalv";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
      "noatime"
    ];
  };

  # LVM activation in preLVMCommands (runs after oci-hardware.nix device settling)
  boot.initrd.preLVMCommands = lib.mkAfter ''
    echo "Activating LVM volume groups..."
    lvm vgscan --mknodes
    lvm vgchange -ay
    lvm lvscan
    sleep 1
  '';

  # Nix settings
  nix.settings.require-sigs = false;
  nix.settings.trusted-users = [
    "root"
    "jrestivo"
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "cgroups"
  ];

  # System packages
  environment.systemPackages = with pkgs; [
    gh
    bat
    claude-code
    gemini-cli
    vim
    git
    htop
    ghostty.terminfo
    eza
    fd
    ripgrep
    fish
  ];

  # Fish as default shell
  programs.fish.enable = true;
  programs.bpftop.enable = true;
  # services.nix-btm.enable = false;

  # User configuration
  users.users.jrestivo = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # root's ssh key for srcbot
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4vzMVS1qxgu+4bMSb3TBNiK9ot+G9DqGDw3dAdhogr root@desktop"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5qlN93RBt99GVy6YDP3OMb7Yu4zwELvT5kvdTRnPzE9txmdxKiMM8eHGw4vBwcbmwY7y1wa+ijXwiT0PbwDUOQvVu8CzWHxBF0pz8LVy7XsBuQr9UtxXVV6D9KBKJJEQjpKgF0LTGOC3LSdHKqlH/4zUaUpE2ZPOaoS01S8YwNfRbr30XDeilMDD5rY0AVlydKFRZIbf/96fdo4HURKcjRMapTdYrdkj++FINCl4IDOId3UQR7Z8qDmx2IC6rOikMNMGwEFvgueCDHDuieqNfHn9LVv8gzCPZ0QtX5Ap+6FPNiUfBXuG1IK7RzeDicGUSXWfKFQImwo6pppArqvtqizEFY6WDBSso5XTveg3Z/gH5/jfMigElVAh8xob/NAW2lv6lHEjXtFVmk3N2Fz425SfXQp2qyaYOPGYohWt1ZwlMdkHYfYGtskaoUd9XCM3GC+aSSLkMPuaXtLS3aJ9R7jcz4sfXdU0s3Vd+jQl7c9n3lGYlZ59aKruUj50QtAs= jrestivo@jrestivo.local"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINE5i3Uv3queOM3VfOCYOU/gnUAU+kZ8GFyn+C5dGcCc justin@restivo.me"
    ];
  };

  # SSH configuration
  services.openssh.settings.PasswordAuthentication = false;
  security.sudo.wheelNeedsPassword = false;

  # Tailscale VPN
  services.tailscale.enable = true;

  # Eternal Terminal for better SSH experience
  services.eternal-terminal = {
    enable = true;
    port = 2022;
  };

  # Open firewall for ET (not opened automatically by the service module)
  networking.firewall.allowedTCPPorts = [ 2022 ];
  # WeebTogether game server (UDP)
  networking.firewall.allowedUDPPorts = [ 7777 ];

  # Caddy reverse proxy to desktop services via Tailscale
  # Tailscale Funnel handles HTTPS termination, Caddy listens locally
  services.caddy = {
    enable = true;
    virtualHosts.":8080" = {
      extraConfig = ''
        # Gonic music server
        @gonic path /gonic /gonic/*
        handle @gonic {
          reverse_proxy https://office-desktop.tail5ca7.ts.net {
            header_up Host {upstream_hostport}
          }
        }

        # Srcbot static files
        @srcbot path /srcbot /srcbot/*
        handle @srcbot {
          reverse_proxy https://office-desktop.tail5ca7.ts.net {
            header_up Host {upstream_hostport}
          }
        }

        # Srcbot-srv static files
        @srcbot-srv path /srcbot-srv /srcbot-srv/*
        handle @srcbot-srv {
          reverse_proxy https://office-desktop.tail5ca7.ts.net {
            header_up Host {upstream_hostport}
          }
        }

        # WeebTogether matchmaker API
        @matchmaker path /matchmaker /matchmaker/*
        handle @matchmaker {
          uri strip_prefix /matchmaker
          reverse_proxy localhost:3000
        }

        handle {
          respond "nixos-arm" 200
        }
      '';
    };
  };

  # Tailscale Funnel to expose Caddy publicly
  services.tailscale.useRoutingFeatures = "both";
  systemd.services.tailscale-funnel = {
    description = "Tailscale Funnel for public HTTPS";
    after = [
      "tailscaled.service"
      "caddy.service"
      "network-online.target"
    ];
    wants = [
      "tailscaled.service"
      "caddy.service"
      "network-online.target"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.tailscale ];
    script = ''
      # Wait for tailscale to be ready
      sleep 5
      # Configure serve with funnel in background mode
      tailscale funnel --bg --https=443 http://localhost:8080
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # Disable networkd wait-online (not needed, interfaces are unmanaged)
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
}

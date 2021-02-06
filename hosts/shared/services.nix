{ config, pkgs, lib, options, ... }:

{
  # OP ssh between all the devices
  services.zerotierone.enable = true;
  services.zerotierone.joinNetworks = [ "af415e486feddf70" ];

  # even more OP ssh between all the devices
  services.tailscale = {
    enable = true;
    /*services.tailscale.port = 1618;*/
  };

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

  services.openssh.passwordAuthentication = false;
  services.openssh.enable = true;
  programs.ssh.forwardX11 = true;
  programs.ssh.setXAuthLocation = true;

  services.xrdp.enable = true;
  networking.firewall.allowedTCPPorts = [ 3389 80 443 444 ];

  services.lorri.enable = true;

  services.gnome3.gnome-keyring.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    #enableNvidia = true;
    enableOnBoot = true;
  };

  boot.plymouth = {
    enable = true;
    /*logo = ''*/
    /*pkgs.fetchurl {*/
    /*url = "https://nixos.org/logo/nixos-hires.png";*/
    /*sha256 = "1ivzgd7iz0i06y36p8m5w48fd8pjqwxhdaavc0pxs7w1g7mcy5si";*/
    /*}'';*/
  };

  services.locate = {
    enable = true;
    locate = pkgs.unstable.mlocate;
    localuser = null; # mlocate does not support this option so it must be null
    interval = "weekly";
    pruneNames = [
      ".git"
        "cache"
        ".cache"
        ".cpcache"
        ".aot_cache"
        ".boot"
        "node_modules"
        "USB"
    ];
    prunePaths = options.services.locate.prunePaths.default ++ [
      "/dev"
      "/lost+found"
      "/nix/var"
      "/proc"
      "/run"
      "/sys"
      "/usr/tmp"
    ];
  };


}

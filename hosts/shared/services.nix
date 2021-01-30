{ config, pkgs, lib, ... }:

{
  # OP ssh between all the devices
  services.zerotierone.enable = true;
  services.zerotierone.joinNetworks = [ "af415e486feddf70" ];

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
  networking.firewall.allowedTCPPorts = [ 3389 ];

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

}

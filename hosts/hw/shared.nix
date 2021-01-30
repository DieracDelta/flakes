{ config, lib, pkgs, ... }:
{

  # from hw
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # steam shit
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  # sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;

  hardware.bluetooth.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
}

{ config, lib, pkgs, ... }:
{

  # from hw
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # steam shit
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;


  services.udev.extraRules =
    ''
      # Rule for all ZSA keyboards
      SUBSYSTEM=="usb", ATTR{idVendor}=="3297", GROUP="plugdev"
      # Rule for the Moonlander
      SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
      # Rule for the Ergodox EZ
      SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="1307", GROUP="plugdev"
      # Rule for the Planck EZ
      SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="6060", GROUP="plugdev"
      '';

  # sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;

  hardware.bluetooth.enable = true;
  hardware.keyboard.zsa.enable = true;

  boot.loader.systemd-boot.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
}

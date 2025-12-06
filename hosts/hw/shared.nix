{
  config,
  lib,
  pkgs,
  ...
}:
{
  # from hw
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # steam shit
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  services.pulseaudio.support32Bit = true;

  hardware.bluetooth.enable = true;
  hardware.keyboard.zsa.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

}

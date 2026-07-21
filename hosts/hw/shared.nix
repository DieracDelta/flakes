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

  # Bluetooth is intentionally disabled; OBEX is masked separately so D-Bus
  # activation cannot start the file-transfer daemon.
  hardware.bluetooth.enable = lib.mkForce false;
  hardware.keyboard.zsa.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

}

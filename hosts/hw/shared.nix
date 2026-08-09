{
  config,
  lib,
  pkgs,
  ...
}:
{
  # from hw
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # Graphics acceleration
  hardware.graphics.enable = true;

  # Bluetooth is intentionally disabled; OBEX is masked separately so D-Bus
  # activation cannot start the file-transfer daemon.
  hardware.bluetooth.enable = lib.mkForce false;
  hardware.keyboard.zsa.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

}

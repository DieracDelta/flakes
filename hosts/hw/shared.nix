{ config, lib, pkgs, ... }:
{
  systemd.extraConfig = "DefaultLimitNOFILE=1024:1048576";


  # environment.memoryAllocator.provider = "jemalloc";


  # from hw
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # steam shit
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  services.pulseaudio.support32Bit = true;
  # zramSwap.enable = true;


  # sound
  # sound.enable = true;
  #hardware.pulseaudio.enable = true;
  #nixpkgs.config.pulseaudio = true;

  hardware.bluetooth.enable = true;
  hardware.keyboard.zsa.enable = true;

  # TODO enable when around in person
  # boot.initrd.systemd.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
}

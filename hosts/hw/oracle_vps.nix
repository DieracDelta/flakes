{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub.device = "/dev/sda";
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

  swapDevices = [
      {
        device = "/swapfile";
        priority = 0;
        size = 7000;
      }
    ];
}

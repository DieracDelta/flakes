{ config, lib, pkgs, ... }:

{
  imports = [./shared.nix];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/sda1";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/5D53-4A61";
      fsType = "vfat";
    };

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 12;

  # end hw file stuff

  hardware.cpu.amd.updateMicrocode = true;

}

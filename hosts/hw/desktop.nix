{ config, lib, pkgs, ... }:

{
  imports = [ ./shared.nix ./gpu_passthrough.nix ];
  #imports = [ ./shared.nix ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" "amdgpu" ];
  boot.extraModulePackages = [ ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  environment.systemPackages = with pkgs; [ trezord trezor-udev-rules python38Packages.trezor_agent python38Packages.trezor ];
  services.trezord.enable = true;
  hardware.opengl.extraPackages = with pkgs; [ amdvlk ];

  fileSystems."/" =
    {
      device = "/dev/sda1";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/5D53-4A61";
      fsType = "vfat";
    };

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 12;
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # end hw file stuff

  hardware.cpu.amd.updateMicrocode = true;

}

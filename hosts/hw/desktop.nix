{ config, lib, pkgs, ... }:

{
  imports = [ ./shared.nix /* ./gpu_passthrough.nix */ ];
  #imports = [ ./shared.nix ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ "amdgpu" ];


  # enable ip forwarding
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  boot.kernelParams = [ "amdgpu.dc=1" ];


  boot.binfmt.emulatedSystems = [
      "aarch64-linux" "armv7l-linux" "riscv64-linux"
  ];
  # boot.kernelPackages = pkgs.linux_6_1linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_5_15;

  # services.xserver.deviceSection = ''
  #        Option "DRI" "3"
  #    '';

  boot.kernelModules = [ "kvm-amd" /* "amdgpu"  */];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback /* akvcam */ ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  environment.systemPackages = with pkgs; [ trezord trezor-udev-rules python310Packages.trezor_agent python310Packages.trezor ];
  services.trezord.enable = true;
  hardware.opengl.extraPackages = with pkgs; [ /* amdvlk */ rocmPackages.clr.icd ];

  environment.variables = {
    ROC_ENABLE_PRE_VEGA = "1";
  };

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

  nix.settings.max-jobs = lib.mkDefault 12;

  # end hw file stuff

  hardware.cpu.amd.updateMicrocode = true;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  hardware.opengl.driSupport = true;

}

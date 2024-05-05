{ config, lib, pkgs, ... }:

{
  imports = [ ./shared.nix /* ./gpu_passthrough.nix */ ];
  #imports = [ ./shared.nix ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [
  "nvidia"
  ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # wakes this shit up
    nvidiaPersistenced = true;
    modesetting.enable = true;
    open = false;
  };


  # enable ip forwarding
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  boot.kernelParams = [/*  "amdgpu.dc=1"  */];


  boot.binfmt.emulatedSystems = [
      "aarch64-linux" "armv7l-linux" /* "riscv64-linux" */
  ];
  # boot.kernelPackages = pkgs.linux_6_1linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_5_15;

  # services.xserver.deviceSection = ''
  #        Option "DRI" "3"
  #    '';

  boot.kernelModules = [ "kvm-amd" /* TODO comment */ ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback /* akvcam */ ];
  services.xserver.videoDrivers = [ /* TODO COMMENT  */ /* "amdgpu" */ "nvidia" ];
  environment.systemPackages = with pkgs; [ trezord trezor-udev-rules python310Packages.trezor_agent python310Packages.trezor ];
  services.trezord.enable = true;
  # environment.sessionVariables.AMD_VULKAN_ICD = "RADV";
  hardware.opengl.extraPackages = with pkgs; [ /* amdvlk */ /* rocmPackages.clr.icd  */];

  environment.variables = { };

  swapDevices = [ ];

  # boot.loader.grub = {
  #   enable = true;
  #   efiSupport = true;
  #   efiInstallAsRemovable = true;
  #   mirroredBoots = [
  #     { devices = [ "nodev"]; path = "/boot"; }
  #   ];
  # };
  # networking.hostId = "84500694";
  #
  boot.loader.systemd-boot.enable = true;
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/2d8d366c-8799-4456-8088-a15b5f905770";
      fsType = "btrfs";
      options = [ "subvol=root"  "compress=zstd" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/2d8d366c-8799-4456-8088-a15b5f905770";
      fsType = "btrfs";
      options = [ "subvol=home"  "compress=zstd" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/2d8d366c-8799-4456-8088-a15b5f905770";
      fsType = "btrfs";
      options = [ "subvol=nix" "noatime"];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/CD38-00CA";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  nix.settings.max-jobs = lib.mkDefault 13;

  # end hw file stuff

  hardware.cpu.amd.updateMicrocode = true;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  hardware.opengl.driSupport = true;

}

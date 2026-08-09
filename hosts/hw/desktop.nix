{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./shared.nix # ./gpu_passthrough.nix
  ];
  #imports = [ ./shared.nix ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "xpad"
  ];
  boot.initrd.kernelModules = [
    "nvidia"
  ];

  # hardware.logitech.wireless.enable = true;
  # hardware.logitech.wireless.enableGraphical = true;

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable.override {
      disable32Bit = true;
    };
    # wakes this shit up
    nvidiaPersistenced = true; # TODO: re-enable after reboot
    modesetting.enable = true;
    open = false;
  };

  # enable ip forwarding
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  boot.kernelParams = [
    # "amdgpu.dc=1"
  ];

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    # "riscv64-linux"
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.kernelPackages = pkgs.linux_6_1linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_5_15;

  # services.xserver.deviceSection = ''
  #        Option "DRI" "3"
  #    '';
  hardware.xpadneo.enable = true;

  boot.kernelModules = [
    "kvm-amd" # TODO comment
    "r8125"
  ];
  boot.blacklistedKernelModules = [ "r8169" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    zenergy
    v4l2loopback # akvcam
    config.boot.kernelPackages.r8125
  ];

  services.xserver.videoDrivers = [
    # TODO COMMENT "amdgpu"
    "nvidia"
  ];
  # environment.sessionVariables.AMD_VULKAN_ICD = "RADV";
  # hardware.opengl.extraPackages = with pkgs; [ /* amdvlk */ /* rocmPackages.clr.icd  */];

  environment.variables = { };

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
  boot.loader.systemd-boot.memtest86.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/2d8d366c-8799-4456-8088-a15b5f905770";
    fsType = "btrfs";
    options = [
      "subvol=root"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/2d8d366c-8799-4456-8088-a15b5f905770";
    fsType = "btrfs";
    options = [
      "subvol=home"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/2d8d366c-8799-4456-8088-a15b5f905770";
    fsType = "btrfs";
    options = [
      "subvol=nix"
      "compress=zstd"
      "noatime"
      "commit=600"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CD38-00CA";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # === 12.7TB Storage HDD (LVM) ===

  # Services partition (btrfs with subvolumes)
  fileSystems."/storage/backups" = {
    device = "/dev/storage-vg/services";
    fsType = "btrfs";
    options = [
      "subvol=@backups"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/storage/media" = {
    device = "/dev/storage-vg/services";
    fsType = "btrfs";
    options = [
      "subvol=@media"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/storage/services" = {
    device = "/dev/storage-vg/services";
    fsType = "btrfs";
    options = [
      "subvol=@services"
      "compress=zstd"
      "noatime"
    ];
  };

  # Music backup LV on backup-vg.
  fileSystems."/storage/music-backup" = {
    device = "/dev/disk/by-label/music-backup";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "nofail"
    ];
  };

  # User partitions (btrfs for easy resize + compression)
  fileSystems."/mnt/siraben-ext" = {
    device = "/dev/storage-vg/siraben";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/home/john/storage" = {
    device = "/dev/storage-vg/john";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
    ];
  };

  # Bind mounts for service data directories
  fileSystems."/var/lib/renderd_share" = {
    device = "/storage/services/renderd_share";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/storage/services" ];
  };

  fileSystems."/var/lib/opentripplanner" = {
    device = "/storage/services/opentripplanner";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/storage/services" ];
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 33;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.dirty_background_bytes" = 67108864; # 64 MiB
    "vm.dirty_bytes" = 268435456; # 256 MiB
    "vm.min_free_kbytes" = 262144; # 256 MiB
    "vm.page-cluster" = 0;
    "vm.swappiness" = 60;
    "vm.watermark_scale_factor" = 125;

  };

  nix.settings.system-features = [
    "nixos-test"
    "benchmark"
    "big-parallel"
    "kvm"
    "gccarch-znver3"
    "gccarch-znver1"
    "gccarch-alderlake"
    "gccarch-x86_64-v3"
    "gccarch-armv7-a"
  ];

  # nixpkgs.hostPlatform = "";
  #
  # nixpkgs.hostPlatform = {
  #     system = "x86_64-linux";
  #     gcc.arch = "gccarch-znver3";
  #     gcc.tune = "gccarch-znver3";
  #   };

  nix.settings.max-jobs = 6;
  nix.settings.cores = 5;
  nix.package = pkgs.nix;

  # end hw file stuff
  #

  hardware.cpu.amd.updateMicrocode = true;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

}

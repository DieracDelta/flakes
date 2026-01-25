# OCI ARM Hardware Module
#
# This module provides hardware support for Oracle Cloud Infrastructure ARM instances
# (VM.Standard.A1.Flex / Ampere A1). It handles:
# - iSCSI boot via iBFT (iSCSI Boot Firmware Table)
# - Mellanox ConnectX-6 network driver
# - Required kernel modules and initrd configuration
# - LVM support for multi-volume setups
# - Optional initrd SSH for emergency access
#
# This is a pure hardware module - no application-specific configuration.
# Use this as a base for any NixOS deployment on OCI ARM.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.oci.hardware;
in
{
  options.oci.hardware = {
    enableLVM = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable LVM support in the initrd. Required for setups using LVM
        to combine boot volume and block volumes.
      '';
    };

    initrdSSH = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable SSH access in the initrd for emergency debugging.
          Useful when LVM or other early-boot services fail.
        '';
      };

      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "SSH public keys authorized to access initrd SSH";
      };

      hostKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to the SSH host key file for initrd SSH.
          This should be generated once and stored securely.
        '';
      };
    };
  };

  config = {
    # OCI NATIVE mode uses iSCSI boot via iBFT (iSCSI Boot Firmware Table)
    # The firmware (iPXE) provides iSCSI target info in iBFT, we need to:
    # 1. Enable network in initrd
    # 2. Load iSCSI modules
    # 3. Use iscsiadm to connect using iBFT parameters

    # Required for iSCSI boot with networkd
    networking.useNetworkd = true;
    networking.useDHCP = false; # Required when useNetworkd = true

    # Enable network in initrd for iSCSI
    boot.initrd.network = {
      enable = true;
      # Keep network up - we need it for the iSCSI root filesystem
      flushBeforeStage2 = false;
      # Use DHCP in initrd
      udhcpc.enable = true;
    };

    boot.initrd.kernelModules = [
      # iSCSI modules for iBFT boot
      "iscsi_tcp"
      "iscsi_ibft" # Auto-configures from iBFT table
      "libiscsi"
      "libiscsi_tcp"
      "scsi_transport_iscsi"
      # SCSI disk support
      "sd_mod"
      # Network drivers for OCI - Mellanox ConnectX-6 (0x15b3:0x101e)
      "mlx5_core"
      # Fallback virtio network (in case different instance type)
      "virtio_net"
    ] ++ lib.optionals cfg.enableLVM [
      # LVM / device-mapper modules
      "dm-mod"
      "dm-snapshot"
      "dm-mirror"
    ];

    # Scripted initrd required for iSCSI (systemd stage1 doesn't support it yet)
    boot.initrd.systemd.enable = false;

    # Debug options - drop to shell on boot failure
    boot.kernelParams = [ "boot.shell_on_fail" ];

    # Add iSCSI tools and debug utilities to initrd
    boot.initrd.extraUtilsCommands = lib.mkMerge [
      ''
        copy_bin_and_libs ${pkgs.openiscsi}/bin/iscsid
        copy_bin_and_libs ${pkgs.openiscsi}/bin/iscsiadm
        copy_bin_and_libs ${pkgs.util-linux}/bin/lsblk

        # Copy required config
        mkdir -p $out/etc/iscsi
        cp ${pkgs.openiscsi}/etc/iscsi/iscsid.conf $out/etc/iscsi/iscsid.conf

        # NSS files for network
        cp -pv ${pkgs.glibc.out}/lib/libnss_files.so.* $out/lib
      ''
      # Add LVM tools when LVM is enabled
      # Note: lvm2 package has binaries in the .bin output, not the default output
      (lib.mkIf cfg.enableLVM ''
        copy_bin_and_libs ${pkgs.lvm2.bin}/bin/lvm
        copy_bin_and_libs ${pkgs.lvm2.bin}/bin/pvcreate
        copy_bin_and_libs ${pkgs.lvm2.bin}/bin/vgcreate
        copy_bin_and_libs ${pkgs.lvm2.bin}/bin/vgchange
        copy_bin_and_libs ${pkgs.lvm2.bin}/bin/vgscan
        copy_bin_and_libs ${pkgs.lvm2.bin}/bin/lvchange
        copy_bin_and_libs ${pkgs.lvm2.bin}/bin/lvscan
      '')
    ];

    boot.initrd.extraUtilsCommandsTest = ''
      $out/bin/iscsiadm --version
    '';

    # Connect to iSCSI target using iBFT before LVM/device detection
    boot.initrd.preLVMCommands = ''
      # Setup minimal /etc for networking
      echo 'root:x:0:0:root:/root:/bin/ash' > /etc/passwd
      echo 'passwd: files' > /etc/nsswitch.conf

      # Setup iSCSI config
      mkdir -p /etc/iscsi /run/lock/iscsi /var/lib/iscsi/nodes /var/lib/iscsi/send_targets /var/lib/iscsi/ifaces

      # Generate initiator name (use iBFT initiator name if available)
      if [ -f /sys/firmware/ibft/initiator/initiator-name ]; then
        cat /sys/firmware/ibft/initiator/initiator-name > /etc/iscsi/initiatorname.iscsi
      else
        echo "InitiatorName=iqn.2024-01.org.nixos:$(hostname)" > /etc/iscsi/initiatorname.iscsi
      fi

      cp $extraUtils/etc/iscsi/iscsid.conf /etc/iscsi/iscsid.conf

      echo "Starting iSCSI daemon..."
      iscsid --foreground --no-pid-file --debug 8 &
      sleep 2

      echo "Connecting to iSCSI target via iBFT..."
      # -m fw reads the iBFT table and logs in automatically
      iscsiadm -m fw --login || {
        echo "iBFT login failed, trying manual discovery..."
        # Fallback: read target info from iBFT sysfs
        if [ -d /sys/firmware/ibft/target0 ]; then
          TARGET_IP=$(cat /sys/firmware/ibft/target0/ip-addr 2>/dev/null)
          TARGET_PORT=$(cat /sys/firmware/ibft/target0/port 2>/dev/null || echo 3260)
          TARGET_NAME=$(cat /sys/firmware/ibft/target0/target-name 2>/dev/null)
          echo "iBFT target: $TARGET_NAME at $TARGET_IP:$TARGET_PORT"
          if [ -n "$TARGET_IP" ] && [ -n "$TARGET_NAME" ]; then
            iscsiadm -m discovery -t sendtargets -p "$TARGET_IP:$TARGET_PORT" --debug 8
            iscsiadm -m node -T "$TARGET_NAME" -p "$TARGET_IP:$TARGET_PORT" --login
          fi
        fi
      }

      # Give time for SCSI devices to appear
      sleep 3
      echo "Block devices after iSCSI login:"
      lsblk || cat /proc/partitions

      # Kill iscsid - it will be restarted properly in stage 2
      pkill -9 iscsid || true
    '';

    # LVM support
    services.lvm.enable = cfg.enableLVM;

    # initrd SSH for emergency access
    boot.initrd.network.ssh = lib.mkIf cfg.initrdSSH.enable {
      enable = true;
      port = 22;
      authorizedKeys = cfg.initrdSSH.authorizedKeys;
      hostKeys = lib.optional (cfg.initrdSSH.hostKeyFile != null) cfg.initrdSSH.hostKeyFile;
    };
  };
}

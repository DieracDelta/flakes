# unused right now... morally speaking should be moved to hardware for desktop only
{ config, pkgs, lib, ... }:
{
  environment.pathsToLink = [ "/share/zsh" ];
  boot.kernelParams = [ "video=efifb:off" "amd_iommu=on" "amd_iommu=pt" "hugepagesz=1G" "hugepages=64"];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  virtualisation.libvirtd.enable = true;
  users.groups.libvirtd.members = [ "root" "jrestivo" ];
  #boot.postBootCommands = ''
    #DEVS="0000:2f:00.0 0000:2f:00.1"

    #for DEV in $DEVS; do
      #echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
    #done
    #modprobe -i vfio-pci
  #'';
  boot.extraModprobeConfig = "options vfio-pci ids=1002:67ef,1002:aae0";
  # TODO make sure the OVMF/OVMF_VARS are uniquely named files otherwise will conflict when you have multiple VMs
  virtualisation.libvirtd.qemuVerbatimConfig = ''
    nvram = [ "${pkgs.OVMF}/FV/OVMF.fd:${pkgs.OVMF}/FV/OVMF_VARS.fd" ]
    user = "jrestivo"
    group = "kvm"
    cgroup_device_acl = [
    "/dev/kvm",
    "/dev/input/by-id/usb-SINO_WEALTH_USB_KEYBOARD-event-kbd",
    "/dev/input/by-id/usb-Logitech_USB_Optical_Mouse-event-mouse",
    "/dev/null", "/dev/full", "/dev/zero",
    "/dev/random", "/dev/urandom",
    "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
    "/dev/rtc","/dev/hpet", "/dev/sev"
    ]
  '';
  boot.kernelPatches = [
    {
      name = "vendor-reset";
      patch = null;
      extraConfig = ''
        FTRACE y
        KPROBES y
        PCI_QUIRKS y
        KALLSYMS y
        KALLSYMS_ALL y
        FUNCTION_TRACER y
      '';
    }
  ];
  boot.extraModulePackages = [ pkgs.linuxPackages_latest.vendor-reset ];
  boot.initrd.availableKernelModules = [ "vendor-reset" "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd"  "amdgpu" ];
  boot.initrd.kernelModules = [ "vendor-reset" "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" "amdgpu"  ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.opengl.driSupport = true;
  hardware.opengl.extraPackages = with pkgs; [
    amdvlk
  ];
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 jrestivo qemu-libvirtd -" ];
}

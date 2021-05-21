# unused right now... morally speaking should be moved to hardware for desktop only
{ config, pkgs, lib, ... }:
{
  environment.pathsToLink = [ "/share/zsh" ];
  boot.kernelParams = [ "amd_iommu=on" ];
  boot.kernelPackages = pkgs.latest_kernel;
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
  virtualisation.libvirtd.enable = true;
  users.groups.libvirtd.members = [ "root" "jrestivo" ];
  boot.extraModprobeConfig = "options vfio-pci ids=1002:731f,1002:ab38";
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
        KALLSYMS_ABSOLUTE_PERCPU y
        KALLSYMS_BASE_RELATIVE y
      '';
    }
  ];
  boot.extraModulePackages = [ pkgs.vendor-reset ];
}

# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{

  environment.etc."containers/policy.json" = {
    mode="0644";
    text=''
      {
        "default": [
          {
            "type": "insecureAcceptAnything"
          }
        ],
        "transports":
          {
            "docker-daemon":
              {
                "": [{"type":"insecureAcceptAnything"}]
              }
          }
      }
    '';
  };

  environment.etc."containers/registries.conf" = {
    mode="0644";
    text=''
      [registries.search]
      registries = ['docker.io', 'quay.io']
    '';
  };

  imports =
    [ # Include the results of the hardware scan.
    /etc/nixos/hardware-configuration.nix
  ];


  # START VFIO
  ##environment.pathsToLink = [ "/share/zsh" ];
  ##boot.kernelParams = [ "amd_iommu=on" ];
  ##boot.kernelPackages = pkgs.linuxPackages_latest;
  ##boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
  ##virtualisation.libvirtd.enable = true;
  ##users.groups.libvirtd.members = [ "root" "jrestivo"];
  ##boot.extraModprobeConfig ="options vfio-pci ids=1002:731f,1002:ab38";
  ##virtualisation.libvirtd.qemuVerbatimConfig = ''
  ##  nvram = [ "${pkgs.OVMF}/FV/OVMF.fd:${pkgs.OVMF}/FV/OVMF_VARS.fd" ]
  ##  user = "jrestivo"
  ##  group = "kvm"
  ##  cgroup_device_acl = [
  ##  "/dev/kvm",
  ##  "/dev/input/by-id/usb-SINO_WEALTH_USB_KEYBOARD-event-kbd",
  ##  "/dev/input/by-id/usb-Logitech_USB_Optical_Mouse-event-mouse",
  ##  "/dev/null", "/dev/full", "/dev/zero",
  ##  "/dev/random", "/dev/urandom",
  ##  "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
  ##  "/dev/rtc","/dev/hpet", "/dev/sev"
  ##  ]
  ##'';
  ##boot.kernelPatches = [ { name = "novi reset patch"; patch = /home/jrestivo/Downloads/nixos/reset_bug_patch.patch; } ];
  # END VFIO

  virtualisation.docker.enable = true;

  boot.loader.systemd-boot.enable = true;

  environment.systemPackages =
    let textPack = with pkgs; [ neovim ];
    wlPack = with pkgs; [ chromium wofi flameshot wev swaylock swayidle gtk3 xdg_utils shared_mime_info wf-recorder grip ];
    cliPack = with pkgs; [ fzf zsh oh-my-zsh ripgrep neofetch tmux playerctl fasd jq haskellPackages.cryptohash-sha256 mosh pstree tree ranger nix-index mpv youtube-dl file fd];
    devPack = with pkgs; [ nodejs rustc cargo git universal-ctags qemu virt-manager libvirt OVMF looking-glass-client nasm lua emacs idea.idea-community john gdb];
    utilsPack = with pkgs; [ binutils gcc gnumake openssl pkgconfig ytop pciutils usbutils lm_sensors liblqr1];
    toolPack = with pkgs; [ pavucontrol keepass pywal pithos ];
    gamingPack = with pkgs; [ steam mesa gnuchess];
    bapPack = with pkgs; [ libbap skopeo python27 m4 z3];
    appPack = with pkgs; [ discord zathura mumble feh mplayer slack weechat llvm gmp.static.dev skypeforlinux spotify browsh firefox keybase keybase-gui kbfs qutebrowser obs-studio graphviz minecraft ];
    pythonPack = with pkgs;
    let my-python-packages = python-packages: with python-packages; [
      pywal jedi flake8 pep8 tesserocr pillow autopep8 xdot
    ]; python-with-my-packages = python37.withPackages my-python-packages; in [python-with-my-packages];
    #in builtins.concatLists [ textPack wlPack cliPack devPack toolPack utilsPack appPack gamingPack bapPack pythonPack ];
    in builtins.concatLists [ textPack wlPack cliPack devPack toolPack utilsPack appPack gamingPack bapPack pythonPack];





  services.gnome3.gnome-keyring.enable = true;


  nix.allowedUsers = [ "jrestivo" ];


  # steam shit
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;



  environment.variables = {
    BROWSER="firefox";
    EDITOR="nvim";
  };

  location.provider = "geoclue2";



  users.users.jrestivo = {
    isNormalUser = true;
    home = "/home/jrestivo";
    shell = pkgs.zsh;
    description = "Justin --the owner-- Restivo";
    extraGroups = [ "wheel" "networkmanager" "sway" "audio" "input" "docker" ];
  };

  fonts.fonts = with pkgs; [
    d2coding
    iosevka
    aileron
  ];

  networking.hostName = "nixos"; # Define your hostname.

  networking.useDHCP = false;
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  services.openssh.enable = true;
  services.openssh.authorizedKeysFiles = [ "/home/jrestivo/.config/authorized_users" ];
  services.openssh.passwordAuthentication = false;

  #package.Overrides = pkgs; {
    #imagemagick7 = pkgs.imagemagick7.override
  #}



  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "19.09"; # Did you read the comment?



  # sway config
  programs.sway.enable = true;
  programs.mosh.enable = true;
}


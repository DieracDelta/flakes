# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{

  imports =
    [ # Include the results of the hardware scan.
    /etc/nixos/hardware-configuration.nix
      ./dotfiles/docker.nix
      ./dotfiles/wayland/sway_service.nix
      /*./dotfiles/gpu_passthrough.nix*/
    ];


  virtualisation.docker.enable = true;

  boot.loader.systemd-boot.enable = true;

  environment.systemPackages =
    let textPack = with pkgs; [ neovim ];
  wlPack = with pkgs; [ chromium wofi flameshot wev swaylock gtk3 xdg_utils shared_mime_info wf-recorder slurp grim ly];
  cliPack = with pkgs; [ fzf zsh oh-my-zsh ripgrep neofetch tmux playerctl fasd jq haskellPackages.cryptohash-sha256 mosh pstree tree ranger nix-index mpv youtube-dl file fd];
  devPack = with pkgs; [ nodejs rustc cargo git universal-ctags qemu virt-manager libvirt OVMF looking-glass-client nasm lua emacs idea.idea-community john gdb direnv ];
  utilsPack = with pkgs; [ binutils gcc gnumake openssl pkgconfig ytop pciutils usbutils lm_sensors liblqr1];
  toolPack = with pkgs; [ pavucontrol keepass pywal pithos ];
  gamingPack = with pkgs; [ steam mesa gnuchess];
  bapPack = with pkgs; [ libbap skopeo python27 m4 z3];
  appPack = with pkgs; [ discord zathura mumble feh mplayer slack weechat llvm gmp.static.dev skypeforlinux spotify browsh firefox keybase keybase-gui kbfs qutebrowser obs-studio graphviz minecraft signal-desktop alacritty ];
  pythonPack = with pkgs;
  let my-python-packages = python-packages: with python-packages; [
    pywal jedi flake8 pep8 tesserocr pillow autopep8 xdot
  ]; python-with-my-packages = python37.withPackages my-python-packages; in [python-with-my-packages];

  swayPack = [
    (pkgs.makeDesktopItem {
     name = "Sway_TESTING";
     desktopName = "Sway";
     comment = "An i3-compatible Wayland Compositor";
     exec = "sway";
     type = "Application";
     })
  ];

  in builtins.concatLists [ textPack wlPack cliPack devPack toolPack utilsPack appPack gamingPack bapPack pythonPack swayPack];

  environment.etc = {
    "sway/config".source = ./dotfiles/wayland/sway_config;
    "rootbar/rootbar_config".source = ./dotfiles/wayland/rootbar/rootbar_config;
    "rootbar/rootbar.css".source = ./dotfiles/wayland/rootbar/rootbar.css;
    "wofi/style.css".source = ./dotfiles/wayland/wofi/wofi_style.css;
    "wofi/config".source = ./dotfiles/wayland/wofi/wofi_config;
    "wofi/wofi_parse.sh".source = ./dotfiles/wayland/wofi/wofi_parse.sh;
    "rootbar/handler_script.lua".source = ./dotfiles/wayland/rootbar/handler_script.lua;
  };



  environment.variables = {
    BROWSER="qutebrowser";
    EDITOR="nvim";
  };

  services.gnome3.gnome-keyring.enable = true;


  nix.allowedUsers = [ "jrestivo" ];


# steam shit
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;



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

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;
  nixpkgs.config.allowUnfree = true;

  services.lorri.enable = true;

  system.stateVersion = "19.09"; # Did you read the comment? No I did not.

    programs.mosh.enable = true;
}


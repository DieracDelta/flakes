{ config, pkgs, lib, pkgset, ... }:

{

  # to get zsh autocomplete to work
  environment.pathsToLink = ["/share/zsh"];


  programs.mosh.enable = true;
  programs.adb.enable = true;
  programs.java.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = let
    haskellPack = with pkgs; [
    (haskellPackages.ghcWithPackages
     (pkgs: [ pkgs.sort pkgs.base pkgs.split pkgs.lens ]))
      haskellPackages.hoogle
      haskellPackages.hlint
      haskellPackages.brittany
      haskellPackages.ghcide
    ];
  texPack = with pkgs;
  [
    (texlive.combine {
     inherit (texlive) scheme-medium lipsum fmtcount datetime;
     })
  ];
  pentestPack = with pkgs; [nmap aircrack-ng];
  textPack = with pkgs; [
      atop
      rnix-lsp
      neovim-nightly
      pulseeffects
      noip
      remmina
      dnsutils
      mkpasswd
      imagemagick
      deepfry
      pkgs.unstable.chromium
      flameshot
      firefox
      vscode
      cachix
      bat
      manix
      dante
      tigervnc
      cargo
      rustup
      rustc
# rustChannels.stable.rust
      hwloc
      ngrok
      nixos-generators
      vscode
      wine
      pdftk
      vimb
# libreoffice
      redshift
      brightnessctl
      arandr
      zoom
      uutils-coreutils
      nix-tree
      android-studio
      nixFlakes
      gimp
      tdesktop
      nixfmt
      clang-tools
      evtest
      cmake
      evemu
      opam
      opencl-headers
      clang
      unzip
      gtk3
      xdg_utils
      shared_mime_info
      emacs
      ];
# wlPack = with pkgs; [
#   flameshot
#   wev
#   swaylock
#   wf-recorder
#   slurp
#   grim
# ];
  xPack = with pkgs; [ maim xclip xmobar libGL libGLU glxinfo ];
  cliPack = with pkgs; [
    fzf
      zsh
      oh-my-zsh
      ripgrep
      neofetch
      tmux
      playerctl
      fasd
      jq
      haskellPackages.cryptohash-sha256
      mosh
      pstree
      tree
      ranger
      nix-index
      mpv
      youtube-dl
      file
      fd
      sd
      tealdeer
      htop
      wget
      ispell
      ];
  devPack = with pkgs; [
    cask
      nodejs
      git
      universal-ctags
      qemu
      virt-manager
      libvirt
      OVMF
      looking-glass-client
      nasm
      lua
      idea.idea-community
      gdb
      direnv
  ];
  utilsPack = with pkgs; [
    binutils
      gcc
      gnumake
      openssl
      pkgconfig
      ytop
      pciutils
      usbutils
      lm_sensors
      liblqr1
      zlib.dev
  ];
  toolPack = with pkgs; [ pavucontrol keepass pywal pithos ];
  gamingPack = with pkgs; [
    cowsay
      steam
      mesa
      gnuchess
      angband
      winetricks
      protontricks
      cabextract
      m4
  ];
# deploymentPack = with pkgs; [hugo];
# bapPack = with pkgs; [ libbap skopeo python27 m4];
  appPack = with pkgs; [
    xorg.xwininfo
      element-desktop
      pipenv
      discord
      zathura
      mumble
      feh
      mplayer
      slack
      weechat
      llvm
      gmp.static.dev
      skypeforlinux
      spotify
      browsh
      keybase
      keybase-gui
      kbfs
      obs-studio
      graphviz
      minecraft
      signal-desktop
      alacritty
      keepass
      mimic
      zoom-us
      ];
  hackPack = with pkgs; [ ghidra-bin john ];
  python37Pack = with pkgs;
  let
    my-python-packages = python-packages:
    with python-packages; [
    pywal
      jedi
      flake8
      pep8
      tesserocr
      pillow
      autopep8
      xdot
      opencv4
      numpy
    ];
  python-with-my-packages = python37.withPackages my-python-packages;
  in [ python-with-my-packages ];

  in builtins.concatLists [
    texPack
    haskellPack
      textPack
# wlPack
      cliPack
      devPack
      toolPack
      utilsPack
      appPack
      gamingPack
      python37Pack
      hackPack
      xPack
      pentestPack
  ];

  fonts.fonts = with pkgs; [
    d2coding
      iosevka
      aileron
      nerdfonts
      fira-code
      fira-code-symbols
      fira-mono
  ];
}

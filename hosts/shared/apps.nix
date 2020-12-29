{ config, pkgs, lib, ... }:

{

  programs.mosh.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = let
    textPack = with pkgs; [
      flameshot

      (haskellPackages.ghcWithPackages
        (pkgs: [ pkgs.sort pkgs.base pkgs.split pkgs.lens ]))
      haskellPackages.hoogle
      haskellPackages.hlint
      haskellPackages.brittany
      haskellPackages.ghcide
      dante

      tigervnc
      (texlive.combine {
        inherit (texlive) scheme-medium lipsum fmtcount datetime;
      })
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
      neovim
      evtest
      cmake
      evemu
      opam
      opencl-headers
    ];
    wlPack = with pkgs; [
      emacs
      flameshot
      wev
      swaylock
      gtk3
      xdg_utils
      shared_mime_info
      wf-recorder
      slurp
      grim
      clang
      unzip
    ];
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
      # latest.firefox-nightly-bin
      firefox
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
    textPack
    wlPack
    cliPack
    devPack
    toolPack
    utilsPack
    appPack
    gamingPack
    python37Pack
    hackPack
    xPack
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

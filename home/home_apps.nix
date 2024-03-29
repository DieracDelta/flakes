{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.profiles.dev;
  haskellPack = with pkgs.haskellPackages;
    let
      ps = p: with p;  [ async base containers lens mtl random stm text transformers unliftio ];
      ghc = ghcWithHoogle ps;
    in
    [
      # threadscope
      # ghc
      # cabal-install
      # hlint
      # ghcide
      # hnix
    ];
  devPack = with pkgs; [
    emacs
    brave
    zellij
    v4l-utils
    #mining
    # ethminer
    # rocm-device-libs
    # rocm-opencl-icd
    # rocm-opencl-runtime
    # rocm-runtime
    # rocm-smi
    # rocm-thunk
    # rocm-comgr
    # rocm-cmake



    innernet


    git-lfs
    yubico-piv-tool
    yubikey-manager-qt
    #nix-extract-revs-from-cache
    #matrix-construct
    github-cli
    #neovitality
    stack
    nixpkgs-fmt
    yubikey-personalization
    _7zz
    # thunderbird
    # hls
    opam
    cmake
    # clang
    #opencl-headers
    llvm
    # cask
    # nodejs
    # universal-ctags
    # nasm
    # lua
    gdb
    # binutils
    /*gcc*/
    gnumake
    openssl
    pkg-config
    dog
    hwinfo
    # lean
  ];
  /* user */
  appPack = with pkgs; [
    idris2
    lshw
    # teams
    # bluejeans-gui
    # blender
    # element-desktop
    # discord
    zathura
    # mumble
    feh
    mplayer
    # slack
    # weechat
    gmp.static.dev
    # skypeforlinux
    # spotify
    browsh
    keybase
    keybase-gui
    kbfs
    # obs-studio
    graphviz
    # minecraft
    signal-desktop
    /*from gytis*/
    alacritty
    vscode
    rust-analyzer
    wally-cli

    yubikey-manager
    keepass
    mimic
    # zoom-us
  ];
  /* user */
  workstationPack = with pkgs; [
    # nyxt
    # zulip
    termite
    pavucontrol
    # pywal
    # pithos
    noip
    remmina
    # firefox
    # pkgs.unstable.chromium
    flameshot
    urlscan
    lynx
    bottom
    # vscode
    dante
    # android-studio
    bottom
    #gimp
    # tdesktop
    exodus
    mpv
    youtube-dl
    pciutils
    usbutils
    lm_sensors
    liblqr1
    zlib.dev
  ];
  embeddedPack = with pkgs; [
    dtc
    patchelf
    # avrdude
    # arduino
    # arduino-cli
    # platformio
    #scala
    metals
    sbt
    #pkgsCross.avr.buildPackages.gcc
  ];
  financialPack = with pkgs; [
    beancount
  ];
  pentestPack = with pkgs; [
    ghidra-bin
    john
    nmap
    aircrack-ng
  ];
  texPack = with pkgs;
    [
      # pdftk
      # (
      #   texlive.combine {
      #     inherit (texlive) scheme-medium lipsum fmtcount datetime;
      #   }
      # )
    ];
  languageserverPack = with pkgs; [
    # shellcheck
    # rnix-lsp
    # nixfmt
    # clang-tools
  ];
  cPack = with pkgs; [
    clang
    valgrind
    perf-tools
  ];
in
{
  options.profiles.dev.enable =
    lib.mkOption {
      description = "Enable custom vim configuration.";
      type = with lib.types; bool;
      default = true;
    };

  config = lib.mkIf cfg.enable {
    home.packages = builtins.concatLists [
      #python38Pack
      # haskellPack
      devPack
      appPack
      workstationPack
      embeddedPack
      pentestPack
      texPack
      languageserverPack
      cPack
      financialPack
    ];
  };

}

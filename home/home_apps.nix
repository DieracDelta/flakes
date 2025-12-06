{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.profiles.dev;
  haskellPack =
    with pkgs.haskellPackages;
    let
      ps =
        p: with p; [
          async
          base
          containers
          lens
          mtl
          random
          stm
          text
          transformers
          unliftio
        ];
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
    # openssl curl xxd age
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
    #yubikey-manager-qt
    #yubioath-flutter
    #nix-extract-revs-from-cache
    #matrix-construct
    github-cli
    #neovitality
    # stack
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
    # gcc
    gnumake
    openssl
    pkg-config
    # dog
    hwinfo
    # lean
  ];
  # user
  appPack = with pkgs; [
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
    keybase
    keybase-gui
    kbfs
    graphviz
    # minecraft
    # signal-desktop
    rust-analyzer
    wally-cli

    # yubikey-manager
    keepass
    mimic
    # zoom-us
  ];
  # user
  workstationPack = with pkgs; [
    ifuse
    termite
    pavucontrol
    noip
    remmina
    flameshot
    # urlscan
    lynx
    bottom
    dante
    bottom
    pciutils
    usbutils
    lm_sensors
    hashcat
    rhash
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
  cPack = with pkgs; [
    clang
    valgrind
    perf-tools
  ];
in
{
  options.profiles.dev.enable = lib.mkOption {
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
      cPack
      financialPack
    ];
  };

}

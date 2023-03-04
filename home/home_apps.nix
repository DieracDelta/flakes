{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.profiles.dev;
  # haskellPack = with pkgs.haskellPackages;
  #   let
  #     ps = p: with p;  [ async base containers lens mtl random stm text transformers unliftio ];
  #     ghc = ghcWithHoogle ps;
  #   in
  #   [
  #     threadscope
  #     ghc
  #     cabal-install
  #     hlint
  #     ghcide
  #     hnix
  #   ];
  devPack = with pkgs; [
    #mining
    ethminer
    rocm-device-libs
    rocm-opencl-icd
    rocm-opencl-runtime
    rocm-runtime
    rocm-smi
    rocm-thunk
    rocm-comgr
    rocm-cmake



    innernet


    git-lfs
    yubico-piv-tool
    yubikey-manager-qt
    #nix-extract-revs-from-cache
    #matrix-construct
    github-cli
    #neovitality
    stack
    nyxt
    nixpkgs-fmt
    yubikey-personalization
    _7zz
    thunderbird
    hls
    opam
    cmake
    clang
    #opencl-headers
    llvm
    cask
    nodejs
    universal-ctags
    nasm
    lua
    idea.idea-community
    gdb
    binutils
    /*gcc*/
    gnumake
    openssl
    pkgconfig
  ];
  /* user if at all ... */
  /*really just an example of how creating python package works..*/
  #python38Pack = with pkgs;
  #let
  #my-python-packages = python-packages:
  #with python-packages; [
    #poetry
    ##coincurve
    ##green
    ##protobuf
    ##pycryptodome
    ##ecdsa
    ##groestlcoin_hash
    ##eth-keyfile
  #];
  #python-with-my-packages = python39.withPackages my-python-packages;
  #in
  #[ python-with-my-packages ];
  /* user */
  appPack = with pkgs; [
    idris2
    lshw
    #thunderbird
    teams
    bluejeans-gui
    blender
    element-desktop
    discord
    zathura
    mumble
    feh
    mplayer
    slack
    weechat
    gmp.static.dev
    skypeforlinux
    spotify
    browsh
    keybase
    keybase-gui
    kbfs
    #libreoffice
    obs-studio
    graphviz
    minecraft
    signal-desktop
    /*from gytis*/
    alacritty
    #lightcord
    #nyxt
    vscode
    rust-analyzer
    wally-cli

    yubikey-manager
    keepass
    mimic
    zoom-us
  ];
  /* user */
  workstationPack = with pkgs; [
    termite
    pavucontrol
    pywal
    pithos
    /*pkgset.inputs.nyxt-pkg.packages.${system}.nyxt*/
    /*nyxt*/
    nextcloud21
    nextcloud-client
    noip
    remmina
    pkgs.unstable.chromium
    flameshot
    #firefox
    # for neomutt
    urlscan
    lynx
    bottom
    nyxt
    vscode
    dante
    vscode
    android-studio
    hyperspace-cli
    bottom
    #gimp
    tdesktop
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
    avrdude
    arduino
    arduino-cli
    platformio
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
      languageserverPack
      cPack
      financialPack
    ];
  };

}

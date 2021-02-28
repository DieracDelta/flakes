{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.profiles.dev;
  haskellPack = with pkgs.haskellPackages;
    let
      ps = p: with p;  [ async base containers lens mtl random stm text transformers unliftio ];
      ghc = ghcWithHoogle ps;
    in
    [
      ghc
      cabal-install
      hlint
      ghcide
      hnix
    ];
  devPack = with pkgs; [
    opam
    cmake
    clang
    opencl-headers
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
  /*python37Pack = with pkgs;*/
  /*let*/
  /*my-python-packages = python-packages:*/
  /*with python-packages; [*/
  /*pywal*/
  /*jedi*/
  /*flake8*/
  /*pep8*/
  /*tesserocr*/
  /*pillow*/
  /*autopep8*/
  /*xdot*/
  /*opencv4*/
  /*numpy*/
  /*];*/
  /*python-with-my-packages = python37.withPackages my-python-packages;*/
  /*in*/
  /*[ python-with-my-packages ];*/
  /* user */
  appPack = with pkgs; [
    thunderbird
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
    libreoffice
    obs-studio
    graphviz
    minecraft
    signal-desktop
    /*from gytis*/
    g-alacritty
    lightcord

    keepass
    mimic
    zoom-us
  ];
  /* user */
  workstationPack = with pkgs; [
    pavucontrol
    keepass
    pywal
    pithos
    /*pkgset.inputs.nyxt-pkg.packages.${system}.nyxt*/
    nyxt
    nextcloud20
    nextcloud-client
    pulseeffects
    noip
    remmina
    pkgs.unstable.chromium
    flameshot
    firefox
    vscode
    dante
    vscode
    android-studio
    gimp
    tdesktop
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
    scala
    metals
    sbt
    pkgsCross.avr.buildPackages.gcc
  ];
  pentestPack = with pkgs; [
    ghidra-bin
    john
    nmap
    aircrack-ng
  ];
  texPack = with pkgs;
    [
      pdftk
      (
        texlive.combine {
          inherit (texlive) scheme-medium lipsum fmtcount datetime;
        }
      )
    ];
  languageserverPack = with pkgs; [
    shellcheck
    rnix-lsp
    nixfmt
    clang-tools
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
      haskellPack
      devPack
      appPack
      workstationPack
      embeddedPack
      pentestPack
      texPack
      languageserverPack
    ];
  };

}

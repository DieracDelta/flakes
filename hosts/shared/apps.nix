{ config, pkgs, lib, ... }:

{

  # to get zsh autocomplete to work
  environment.pathsToLink = [ "/share/zsh" ];


  programs.mosh.enable = true;
  programs.adb.enable = true;
  programs.java.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    let
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
          pdftk
          (texlive.combine {
            inherit (texlive) scheme-medium lipsum fmtcount datetime;
          })
        ];
      embeddedPack = with pkgs; [ g-alacritty arduino arduino-cli platformio scala metals sbt ];
      pentestPack = with pkgs; [
        ghidra-bin
        john
        nmap
        aircrack-ng
      ];
      languagePack = with pkgs; [
        opam
        cmake
        clang
        opencl-headers
      ];
      languageserverPack = with pkgs; [
        shellcheck
        rnix-lsp
        nixfmt
        clang-tools
      ];
      miscPack = with pkgs; [
        /*pkgset.inputs.nyxt-pkg.packages.${system}.nyxt*/
        /*nyxt*/
        pulseeffects
        noip
        remmina
        pkgs.unstable.chromium
        flameshot
        firefox
        vscode
        dante
        tigervnc
        hwloc
        nix-du
        nox
        ngrok
        vscode
        zoom
        android-studio
        gimp
        tdesktop
        evemu
        gtk3
        xdg_utils
        shared_mime_info
      ];
      wlPack = with pkgs; [
        flameshot
        wev
        swaylock
        wf-recorder
        slurp
        grim
      ];
      xPack = with pkgs; [
        maim
        xclip
        xmobar
        libGL
        libGLU
        glxinfo
      ];
      cliPack = with pkgs; [
        nixpkgs-fmt
        zsh-forgit
        exa
        nixos-generators
        evtest
        redshift
        emacs
        unzip
        nix-tree
        nixFlakes
        brightnessctl
        arandr
        fzf
        cachix
        bat
        manix
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
        atop
        hunter
        neovim-nightly
        fd
        sd
        tealdeer
        dnsutils
        imagemagick
        deepfry
        mkpasswd
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
        wine
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
        blender
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
        in
        [ python-with-my-packages ];

    in
    builtins.concatLists [
      languagePack
      languageserverPack
      embeddedPack
      texPack
      haskellPack
      miscPack
      # wlPack
      cliPack
      devPack
      toolPack
      utilsPack
      appPack
      gamingPack
      python37Pack
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

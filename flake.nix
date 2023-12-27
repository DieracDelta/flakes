{

  description = "A highly awesome system configuration.";

  inputs = {
    nyxt-src = {
      url = "github:atlas-engineer/nyxt";
      flake = false;
    };
    jj = {
      url = "github:martinvonz/jj";
      flake = true;
    };
    master = {
      # url = "github:NixOS/nixpkgs?rev=317dde2ba4c7d998ae94289b3fc0118814eb9697";
      url = "github:NixOS/nixpkgs/master";
    };
    nix = {
      url = "github:NixOS/nix";
    };
    alacritty = {
      url = "github:zachcoyle/alacritty-nightly";
    };
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs = {
      url = "github:NixOS/nixpkgs/master";
    };
    ospm-src = {
      url = "github:atlas-engineer/ospm";
      flake = false;
    };
    ndebug-src = {
      url = "github:atlas-engineer/ndebug";
      flake = false;
    };
    nsymbols-src = {
      url = "github:atlas-engineer/nsymbols";
      flake = false;
    };
    lisp-unit2-src = {
      url = "github:AccelerationNet/lisp-unit2";
      flake = false;
    };

    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "master";
    };

    hls = {
      url = "github:jkachmar/easy-hls-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mailserver =
      {
        url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
        inputs.nixpkgs.follows = "master";
        inputs.utils.follows = "flake-utils";
      };

    # Solarized mutt colorschemes.
    mutt-colors-solarized = {
      url = "github:altercation/mutt-colors-solarized";
      flake = false;
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "master";
      inputs.flake-utils.follows = "flake-utils";
    };

    my-nvim = {
      url = "github:DieracDelta/vimconfig";
      # inputs.nixpkgs.follows = "master";
    };

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "master";
    };

    flake-utils = {
      url = github:numtide/flake-utils;
      inputs.nixpkgs.follows = "master";
    };

    nix-doom-emacs = {
      url = "github:vlaci/nix-doom-emacs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "master";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "master";
    };

    nix-fast-syntax-highlighting = {
      url = "github:zdharma-continuum/fast-syntax-highlighting";
      flake = false;
      inputs.nixpkgs.follows = "master";
    };

    nix-zsh-shell-integration = {
      url = "github:chisui/zsh-nix-shell";
      flake = false;
      inputs.nixpkgs.follows = "master";
    };

    rust-filehost = {
      url = "github:DieracDelta/filehost_rust";
      inputs.nixpkgs.follows = "master";
      inputs.naersk.follows = "naersk";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.utils.follows = "flake-utils";
    };

    vendor-reset = {
      url = "github:gnif/vendor-reset";
      flake = false;
    };

  };

  outputs =
    inputs@{ self
    , nyxt-src
    , ospm-src
    , ndebug-src
    , nsymbols-src
    , lisp-unit2-src
    , master
    , nixpkgs
    , rust-overlay
    , home-manager
    , emacs-overlay
    , nix-doom-emacs
    , colmena
    , sops-nix
    , rust-filehost
    , mailserver
    , mutt-colors-solarized
    , vendor-reset
    , darwin
    , alacritty
    , my-nvim
    , jj
    , ...
    }:
    let
      inherit (nixpkgs) lib;
      system_x86 = "x86_64-linux";
      system = system_x86;
      stable-pkgs = import ./overlays;

      utils = import ./utility-functions.nix {
        inherit lib system pkgs inputs self;
        nixosModules = nixosModules;
      };
      pkgs = (utils.pkgImport nixpkgs overlays);

      hmImports = [
        inputs.nix-doom-emacs.hmModule
        ./home/home.nix
      ];

      unstable-pkgs = (utils.pkgImport master [ stable-pkgs ]);
      nix-ssh-serve =
        (builtins.fetchurl {
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/c3850345cfc590763fae6f4aecfdc66f7f2c2478/nixos/modules/services/misc/nix-ssh-serve.nix";
          sha256 = "169zq4lzsc9kk7b2h37xxvzan1cy6shckjg91pg5hjhdfpxpdckg";
        });

      mkDevelopModule = mod: src: {
        disabledModules = [ mod ];
        # point directly to the file
        imports = [ "${src}" ];
      };
      nixosModules = (hostname: [
        (_: {
          imports = [ (mkDevelopModule "services/misc/nix-ssh-serve.nix" nix-ssh-serve) ];
          nix.sshServe = {
            enable = true;
            write = true;
            keys = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQClm+SMN9Bg1HZ+MjH1VQYEXAnslGWT9564pj/KGO79WMQLUxdp3WWa1hQadf2PleAIEFEul3knrpRSEK3yHcCk3g+sCh3XIJcFZLesswe0V+kCAw+JBSd18ESJ4Qko+iDK95cDzucLFwXB10FMVKQCrX90KR+Fp6s6eJHcZGmpxTPgNulDpAjM2APluM3xBCe6zZzt+iNIzn3J8PRKbpNNbuw/LMRU8+udrGbLavUMcSk7ER9pAyLGhz//9aHWDPu7ZRje+vTWgnGFpzbtEzdjnP+2v45nLKWG7o7WdTAsAR8WSccjtNoBiVgSmpHr07zJ0/gTeL4PUkk3lbtzF/PdtTQGm3Ng4SjOBlhRVaTuKBlF2X/Rwq+W4LCbHVgA79MyhJxL2TDbKBPUSLfckqxP89e8Q7iQ4XjIHqVb50ojNNLGcOQRrHq14Twwx/ZDDQvMXCsLwM6vyoYa8KdSaASEr1clx78qNp9PHGlr+UztW+EsoZI7j1tzcHMmq2BSK90= matthew@t480"
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD6NXqyw4YtT7ptMZn9sJJLQS+RrBH+vi0bMX0o915f8VGCwfC1qbgRPe40PKPEYPDUdQytzHCLqu5EDJx2ize5K1Wci1iL1UMcw1btZzuBo6ez9yWmJS5okBALJlFxqNqYMm1GCGC3x0vhjw38xL3+7rAfA9XA+BALAEpGHAyrDDfrOzfjtnb/aLpovOzQ8uCPp7YZQvQyafT4qQdt2XFMiexWx6l9mmELeYvzWpN22SLaGm8JlfnJ6Yxs5bdLcpGLNUCfBh6bl/FqZL0LH8cs1wbGy/wGyjdn55vpq4CGiqyLb/cgPdCfY+mNAiaCunGFSvY8p3T9hamGoWHxcJqjPTJ5jDTFbz3kdtLccYfz1zmIJZRqhVjIzMm4PlVuoSbCBWS7Lb5kSDcDDhuLstOe5AIe3KBDRAK9wKyZGCEXIpTwe+hprokHlUmvMhMMTgw8B/Ib3B661claT5kno4pMxViZKpD9H8IYjAXPLB6NleI74Kpqe4KEI0EsW+dDKiv+IoDQEd32RzU1eeEvCwTrPr/kqfAo13tam9QW05v2jPgIMBixuCj7JrvpEWe0fN6itwo4W0rXMRuPwDIAZm6IvO4AcvA+K+Fg9OTGnt71Ncr5j7UCEGQgmyjiRiwEfVfX2IpTrq4nGZDGVheXuLB93QVd9dfLExuPkx58VIy+Hw=="
            ];
          };
        })
        mailserver.nixosModule
        (import ./custom_modules)
        sops-nix.nixosModules.sops
        /* for hardware*/
        nixpkgs.nixosModules.notDetected
        home-manager.nixosModules.home-manager
        ({
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jrestivo = {
            imports = hmImports ++ [ (./. + "/hosts/${hostname}.hm.nix") ];
          };
        })
      ]);
      overlays = [
        stable-pkgs
        emacs-overlay.overlay
        (final: prev: {
          hls = inputs.hls.defaultPackage.${system};
        })

        colmena.overlay


        (final: prev: {
          nvim = my-nvim.defaultPackage.x86_64-linux;
          mutt-colors-solarized = inputs.mutt-colors-solarized;
          nix-fast-syntax-highlighting =
            {
              name = "fast-sytax-highlighting";
              file = "fast-syntax-highlighting.plugin.zsh";
              src = "${inputs.nix-fast-syntax-highlighting.outPath}";
            };
          nix-zsh-shell-integration =
            {
              name = "zsh-shell-integration";
              file = "nix-shell.plugin.zsh";
              src = "${inputs.nix-zsh-shell-integration.outPath}";
            };
          rust-filehost = inputs.rust-filehost.packages.${system}.filehost;
        })
        (final: prev:
          {
            ethminer = unstable-pkgs.ethminer.overrideAttrs (prevAttrs:
              {
                cmakeFlags = prevAttrs.cmakeFlags ++ [ "-DUSE_SYS_OPENCL=ON" "-DUSE_SYS_OPENCL=ON" ];
              }
            );
          }
        )
        (final: prev: {
          inherit (unstable-pkgs) manix maim nextcloud21 nix-du tailscale zerotierone zsa-udev-rules wally-cli rust-cbindgen discord alacritty linuxPackages_5_11 imagemagick hyperspace-cli bottom android-studio exodus innernet thunderbird rocm-device-libs rocm-opencl-icd rocm-opencl-runtime rocm-runtime rocm-smi rocm-thunk rocm-comgr rocm-cmake;
          unstable = unstable-pkgs;
        })
      ];

    in
    {


      homeConfigurations = {
        jrestivo =
          home-manager.lib.homeManagerConfiguration {
            inherit system;
            homeDirectory = /home/jrestivo;
            username = "jrestivo";
            configuration = { pkgs, ... }: {
              imports = hmImports;
              nixpkgs.overlays = overlays;
            };
          };
      };

      devShell.${system} =
        let xmonadPkgs = import ./home/xmonad/extraPackages.nix; in
        pkgs.mkShell {
          # imports all files ending in .asc/.gpg and sets $SOPS_PGP_FP.
          sopsPGPKeyDirs = [
            "./secrets"
          ];
          nativeBuildInputs = [
            (pkgs.callPackage sops-nix { }).sops-pgp-hook
          ];
          buildInputs = [ pkgs.sops (pkgs.haskellPackages.ghcWithHoogle xmonadPkgs) ];
          shellhook = "zsh";
        };

      /*very simply get all the stuff in hosts/directory to provide as outputs*/
      nixosConfigurations =
        let
          dirs = lib.filterAttrs (name: fileType: (fileType == "regular") && (lib.hasSuffix ".nixos.nix" name)) (builtins.readDir ./hosts);
          fullyQualifiedDirs = (lib.mapAttrsToList (name: _v: ./. + "/hosts/${name}") dirs);
        in
        utils.buildNixosConfigurations fullyQualifiedDirs;

      # deployment stuff
      deploy.nodes =
        let
          nodes = [
            {
              ip_addr = "100.100.105.124";
              host = "laptop";
            }
            {
              ip_addr = "100.107.190.11";
              host = "desktop";
            }
            {
              ip_addr = "100.80.195.77";
              host = "oracle_vps_1";
            }
            {
              ip_addr = "150.136.52.94";
              host = "oracle_vps_2";
            }
          ];

          gen_node =
            (_node@{ ip_addr, host, ... }:
              {
                ${host} = {
                  hostname = "${ip_addr}";
                  profiles = {
                    system = {
                      sshUser = "root";
                      user = "root";
                      # path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${host};
                      path = [];
                    };
                  };
                };
              });
          results = map gen_node nodes;
        in
        builtins.foldl' pkgs.lib.mergeAttrs { } (results);

      # checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      darwinConfigurations."jrestivo-2" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jrestivo = {
              imports = [ inputs.nix-doom-emacs.hmModule ./home/darwin];
            };
          }
          ./darwin/config.nix
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              jj.overlays.default
              colmena.overlay
              (final: prev: {
                webkitgtk = prev.stdenv.mkDerivation rec {
                  pname = "webkitgtk";
                  version = "2.32.1";

                  src = prev.fetchurl {
                    url =
                      "https://webkitgtk.org/releases/${pname}-${version}.tar.xz";
                    sha256 =
                      "05v9hgpkc6mi2klrd8nqql1n8xzq8rgdz3hvyy369xkhgwqifq8k";
                  };
                  patches = [
                    (prev.fetchpatch {
                      url =
                        "https://github.com/WebKit/WebKit/commit/94cdcd289b993ed4d39c17d4b8b90db7c81a9b10.diff";
                      sha256 =
                        "sha256-ywrTEjf3ATqI0Vvs60TeAZ+m58kCibum4DamRWrQfaA=";
                      excludes = [ "Source/WebKit/ChangeLog" ];
                    })
                    (prev.fetchpatch {
                      url =
                        "https://bug-225856-attachments.webkit.org/attachment.cgi?id=428797";
                      sha256 =
                        "sha256-ffo5p2EyyjXe3DxdrvAcDKqxwnoqHtYBtWod+1fOjMU=";
                      excludes = [ "Source/WebCore/ChangeLog" ];
                    })
                    ./patches/428774.patch # https://bug-225850-attachments.webkit.org/attachment.cgi?id=428774
                    (prev.fetchpatch {
                      url =
                        "https://bug-225850-attachments.webkit.org/attachment.cgi?id=428776";
                      sha256 =
                        "sha256-ryNRYMsk72SL0lNdh6eaAdDV3OT8KEqVq1H0j581jmQ=";
                      excludes = [ "Source/WTF/ChangeLog" ];
                    })
                    (prev.fetchpatch {
                      url =
                        "https://bug-225850-attachments.webkit.org/attachment.cgi?id=428778";
                      sha256 =
                        "sha256-78iP+T2vaIufO8TmIPO/tNDgmBgzlDzalklrOPrtUeo=";
                      excludes = [ "Source/WebKit/ChangeLog" ];
                    })
                    (prev.fetchpatch {
                      url =
                        "https://bug-227360-attachments.webkit.org/attachment.cgi?id=432180";
                      sha256 =
                        "sha256-1JLJKu0G1hRTzqcHsZgbXIp9ZekwbYFWg/MtwB4jTjc=";
                      excludes = [ "Source/WebKit/ChangeLog" ];
                    })
                  ];

                  outputs = [ "out" "dev" ];

                  preConfigure = lib.optionalString
                    (prev.stdenv.hostPlatform != prev.stdenv.buildPlatform) ''
                      # Ignore gettext in cmake_prefix_path so that find_program doesn't
                      # pick up the wrong gettext. TODO: Find a better solution for
                      # this, maybe make cmake not look up executables in
                      # CMAKE_PREFIX_PATH.
                      cmakeFlags+=" -DCMAKE_IGNORE_PATH=${
                        lib.getBin prev.gettext
                      }/bin"
                    '';

                  nativeBuildInputs = with prev; [
                    bison
                    cmake
                    gettext
                    gobject-introspection
                    gperf
                    ninja
                    perl
                    perl.pkgs.FileCopyRecursive # used by copy-user-interface-resources.pl
                    pkg-config
                    python3
                    ruby
                    glib # for gdbus-codegen
                    wrapGAppsHook # for MiniBrowser
                  ];

                  buildInputs = with prev; [
                    at-spi2-core
                    enchant2
                    libepoxy
                    gnutls
                    gst_all_1.gst-plugins-bad
                    gst_all_1.gst-plugins-base
                    (harfbuzz.override { withIcu = true; })
                    libGL
                    libGLU
                    mesa # for libEGL headers
                    libgcrypt
                    libgpg-error
                    libidn
                    libintl
                    lcms2
                    libtasn1
                    libwebp
                    libxkbcommon
                    libxml2
                    libxslt
                    libnotify
                    nettle
                    openjpeg
                    p11-kit
                    pcre
                    sqlite
                    woff2
                    libedit
                    readline
                    glib-networking # for MiniBrowser
                    geoclue2
                    libsecret
                  ];

                  propagatedBuildInputs = with prev; [ gtk3 libsoup ];

                  cmakeFlags = [
                    "-DENABLE_INTROSPECTION=ON"
                    "-DPORT=GTK"
                    "-DUSE_SYSTEMD=OFF"
                    "-DUSE_LIBHYPHEN=OFF"
                    "-DENABLE_MINIBROWSER=ON"
                    "-DLIBEXEC_INSTALL_DIR=${
                      placeholder "out"
                    }/libexec/webkit2gtk"
                    # "-DUSE_SOUP2"
                    "-DUSE_LIBSECRET=ON"
                    "-DENABLE_GAMEPAD=OFF"
                    "-DENABLE_JOURNALD_LOG=OFF"
                    "-DENABLE_QUARTZ_TARGET=ON"
                    "-DENABLE_X11_TARGET=OFF"
                    "-DUSE_APPLE_ICU=OFF"
                    "-DUSE_OPENGL_OR_ES=OFF"
                    "-DENABLE_GTKDOC=OFF"
                    "-DENABLE_VIDEO=ON"
                  ];

                  postPatch = ''
                    patchShebangs .
                    # It needs malloc_good_size.
                    sed 22i'#include <malloc/malloc.h>' -i Source/WTF/wtf/FastMalloc.h
                    # <CommonCrypto/CommonRandom.h> needs CCCryptorStatus.
                    sed 43i'#include <CommonCrypto/CommonCryptor.h>' -i Source/WTF/wtf/RandomDevice.cpp
                  '';

                  postFixup = ''
                    # needed for TLS and multimedia functionality
                    wrapGApp $out/libexec/webkit2gtk/MiniBrowser --argv0 MiniBrowser
                  '';

                  # we only want to wrap the MiniBrowser
                  dontWrapGApps = true;
                  requiredSystemFeatures = [ "big-parallel" ];
                };
                nyxt-asdf = final.lispPackages_new.build-asdf-system {
                  pname = "nyxt-asdf";
                  version = inputs.nyxt-src.rev;
                  src = inputs.nyxt-src;
                  systems = [ "nyxt-asdf" ];
                  lisp = final.lispPackages_new.sbcl;
                };
                ndebug = final.lispPackages_new.build-asdf-system {
                  pname = "ndebug";
                  version = inputs.ndebug-src.rev;
                  src = inputs.ndebug-src;
                  lisp = final.lispPackages_new.sbcl;
                  lispLibs = with final.lispPackages_new.sbclPackages; [
                    dissect
                    trivial-custom-debugger
                    trivial-gray-streams
                    bordeaux-threads
                  ];
                };
                nsymbols = final.lispPackages_new.build-asdf-system {
                  pname = "nsymbols";
                  version = inputs.nsymbols-src.rev;
                  src = inputs.nsymbols-src;
                  lisp = final.lispPackages_new.sbcl;
                  lispLibs = with final.lispPackages_new.sbclPackages; [
                    closer-mop
                  ];
                };
                lisp-unit2 =
                  prev.lispPackages_new.sbclPackages.lisp-unit2.overrideLispAttrs
                  (_: {
                    version = inputs.lisp-unit2-src.rev;
                    src = inputs.lisp-unit2-src;
                  });
                  amethyst =
                    prev.stdenv.mkDerivation (finalAttrs: {
                      pname = "Amethyst-bin";
                      version = "0.19.0";

                      src = prev.fetchurl {
                        url = "https://github.com/ianyh/Amethyst/releases/download/v0.19.0/Amethyst.zip";
                        sha256 = "sha256-LdMfySoPpY4fPcDyGFP5xv5/s4a1XoleA7kHKhykZpA=";
                      };

                      nativeBuildInputs = [ prev.unzip ];

                      phases = [ "buildPhase" "installPhase"];

                      buildPhase = ''
                        cp $src ./Amethyst.zip
                        unzip Amethyst.zip
                      '';

                      installPhase = ''
                        mkdir -p $out/Applications
                        mv * $out/Applications/
                      '';

                      # preferLocalBuild = true;

                      meta = with lib; {
                        description = "Automatic tiling window manager for macOS à la xmonad";
                        homepage = "https://ianyh.com/amethyst/";
                        license = licenses.mit;
                      };
                    });
                hu_dot_dwim_dot_defclass-star =
                  prev.lispPackages_new.sbclPackages.hu_dot_dwim_dot_defclass-star.overrideLispAttrs (_: {
                    src = final.fetchFromGitHub {
                      owner = "hu-dwim";
                      repo = "hu.dwim.defclass-star";
                      rev = "2698bd93073f9ba27583351221a3a087fb595626";
                      sha256 =
                        "0v6bj3xbcpz98bkv3a2skz2dh0p50mqaflgkfbrzx1dzbkl1630y";
                    };
                  });
                ospm = final.lispPackages_new.build-asdf-system {
                  version = inputs.ospm-src.rev;
                  src = inputs.ospm-src;
                  pname = "ospm";
                  lisp = final.lispPackages_new.sbcl;
                  lispLibs = with final.lispPackages_new.sbclPackages;
                    [
                      alexandria
                      calispel
                      local-time
                      moptilities
                      named-readtables
                      osicat
                      serapeum
                      trivia
                    ] ++ [ final.hu_dot_dwim_dot_defclass-star ];
                };
               nyxt-3 = final.lispPackages_new.build-asdf-system {
                  pname = "nyxt";
                  version = inputs.nyxt-src.rev;
                  src = inputs.nyxt-src;
                  lisp = final.lispPackages_new.sbcl;
                  systems = [
                    "nyxt"
                    "nyxt/history-tree"
                    "nyxt/class-star"
                    "nyxt/prompter"
                    "nyxt/tests"
                    "nyxt/history-tree/tests"
                    "nyxt/class-star/tests"
                    "nyxt/prompter/tests"
                  ];
                  lispLibs = with final.lispPackages_new.sbclPackages;
                    [
                      alexandria
                      bordeaux-threads
                      calispel
                      cl-base64
                      cl-containers
                      cl-css
                      cl-custom-hash-table
                      enchant
                      cl-gopher
                      cl-html-diff
                      cl-json
                      cl-ppcre
                      cl-ppcre-unicode
                      cl-prevalence
                      cl-qrencode
                      str
                      cl-tld
                      closer-mop
                      clss
                      cluffer
                      dexador
                      flexi-streams
                      iolib
                      lass
                      local-time
                      log4cl
                      lparallel
                      montezuma
                      moptilities
                      named-readtables
                      nfiles
                      nhooks
                      nkeymaps
                      parenscript
                      phos
                      plump
                      quri
                      serapeum
                      swank
                      spinneret
                      trivia
                      trivial-clipboard
                      trivial-features
                      trivial-garbage
                      trivial-package-local-nicknames
                      trivial-types
                      uiop
                      unix-opts
                      cl-cffi-gtk
                      cl-webkit2
                      mk-string-metrics
                      dissect
                      py-configparser
                      slynk
                    ] ++ (with final; [
                      hu_dot_dwim_dot_defclass-star
                      nyxt-asdf
                      ndebug
                      ospm
                      lisp-unit2
                      nsymbols
                    ]);
                };
                # starship = master.legacyPackages.aarch64-darwin.starship;
                nvim = my-nvim.defaultPackage.aarch64-darwin;
                nixVeryUnstable = inputs.master.legacyPackages.aarch64-darwin.nixUnstable;
                # nix = inputs.nix.packages.aarch64-darwin.nix.overrideAttrs (old: {
                #   preInstallCheck = '' echo "exit 99" > tests/gc-non-blocking.sh '';
                # });
                mutt-colors-solarized = inputs.mutt-colors-solarized;
                nix-fast-syntax-highlighting =
                  {
                    name = "fast-sytax-highlighting";
                    file = "fast-syntax-highlighting.plugin.zsh";
                    src = "${inputs.nix-fast-syntax-highlighting.outPath}";
                  };
                nix-zsh-shell-integration =
                  {
                    name = "zsh-shell-integration";
                    file = "nix-shell.plugin.zsh";
                    src = "${inputs.nix-zsh-shell-integration.outPath}";
                  };
              })
            ];
          }
        ];
      };

      # THIS IS WHERE NIXPKGS COMES FROM
      packages."${system}" = (stable-pkgs null pkgs);
    };

}

{

  description = "A highly awesome system configuration.";

  inputs = {
    nix = {
      url = "github:NixOS/nix";
    };
    alacritty = {
      url = "github:zachcoyle/alacritty-nightly";
    };
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    unstable = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    nixpkgs = {
      url = "path:/home/jrestivo/nixpkgs";
    };

    naersk = {
      url = github:nmattia/naersk;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hls = {
      url = "github:jkachmar/easy-hls-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rnix-lsp = {
      url = "github:nix-community/rnix-lsp";
      inputs.naersk.follows = "naersk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mailserver =
      {
        url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.utils.follows = "flake-utils";
      };

    # Solarized mutt colorschemes.
    mutt-colors-solarized = {
      url = "github:altercation/mutt-colors-solarized";
      flake = false;
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    my-nvim = {
      url = "github:DieracDelta/vimconfig";
    };

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils = {
      url = github:numtide/flake-utils;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-doom-emacs = {
      url = "github:vlaci/nix-doom-emacs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
    };

    deploy-rs = {
      inputs.naersk.follows = "naersk";
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deepfry = {
      url = "github:DieracDelta/deepfry";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-fast-syntax-highlighting = {
      url = "github:zdharma-continuum/fast-syntax-highlighting";
      flake = false;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-zsh-shell-integration = {
      url = "github:chisui/zsh-nix-shell";
      flake = false;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-filehost = {
      url = "github:DieracDelta/filehost_rust";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.naersk.follows = "naersk";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.utils.follows = "flake-utils";
    };

  };

  outputs =
    inputs@{ self
    , nixpkgs
    , rust-overlay
    , home-manager
    , emacs-overlay
    , nix-doom-emacs
    , deploy-rs
    , sops-nix
    , rust-filehost
    , mailserver
    , mutt-colors-solarized
    , darwin
    , alacritty
    , my-nvim
    , deepfry
    , ...
    }:
    let
      inherit (nixpkgs) lib;
      inherit (lib) recursiveUpdate;
      system_x86 = "x86_64-linux";
      system_arm = "aarch64-linux";
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

      unstable-pkgs = (utils.pkgImport nixpkgs [ stable-pkgs ]);

      mkDevelopModule = mod: src: {
        disabledModules = [ mod ];
        # point directly to the file
        imports = [ "${src}" ];
      };
      nixosModules = (hostname: [
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



        (final: prev: {
          inherit (deploy-rs.packages.${system}) deploy-rs;
          deepfry = inputs.deepfry.defaultPackage.x86_64-linux;
          nvim = my-nvim.defaultPackage.x86_64-linux;
          #neovitality = neovitality.defaultPackage.${system};
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
          buildInputs = [ pkgs.sops /* (pkgs.haskellPackages.ghcWithHoogle xmonadPkgs) */ ];
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
                      path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${host};
                    };
                  };
                };
              });
          results = map gen_node nodes;
        in
        builtins.foldl' pkgs.lib.mergeAttrs { } (results);

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      darwinConfigurations."jrestivo-2" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jrestivo = import ./home/darwin;
          }
          ./darwin/config.nix
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              inputs.rust-overlay.overlay
              (final: prev: {
                nvim = my-nvim.defaultPackage.aarch64-darwin;
                #nixVeryUnstable = inputs.master.legacyPackages.aarch64-darwin.nixUnstable;
                nix = inputs.nix.packages.aarch64-darwin.nix.overrideAttrs (old: {
                  preInstallCheck = '' echo "exit 99" > tests/gc-non-blocking.sh '';
                });
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
                yabai =
                  let
                    buildSymlinks = prev.runCommand "build-symlinks" { } ''
                      mkdir -p $out/bin
                      ln -s /usr/bin/xcrun /usr/bin/xcodebuild /usr/bin/tiffutil /usr/bin/qlmanage $out/bin
                    ''; in
                  prev.yabai.overrideAttrs (old: {
                    src = prev.fetchFromGitHub {
                      owner = "koekeishiya";
                      repo = "yabai";
                      rev = "5317b16d06e916f0e3844d3fe33d190e86c96ba9";
                      sha256 = "sha256-yl5a6ESA8X4dTapXGd0D0db1rhwhuOWrjFAT1NDuygo=";
                    };
                    buildInputs = with prev.darwin.apple_sdk.frameworks; [ Carbon Cocoa ScriptingBridge prev.xxd SkyLight ];
                    nativeBuildInputs = [ buildSymlinks ];
                  });
              })
            ];
          }
        ];
      };

      # THIS IS WHERE NIXPKGS COMES FROM
      packages."${system}" = (stable-pkgs null pkgs);
    };

}

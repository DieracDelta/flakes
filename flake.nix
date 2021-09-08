{

  description = "A highly awesome system configuration.";

  inputs = {

    master = {
      url = "github:NixOS/nixpkgs/master";
    };
    unstable = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    nixpkgs = {
      url = "github:NixOS/nixpkgs/release-21.05";
    };

    naersk = {
      url = github:nmattia/naersk;
      inputs.nixpkgs.follows = "master";
    };

    hyperspace = {
      #url = github:ngi-nix/hyperspace/yarn2nix;
      url = "path:/home/jrestivo/SoN/malte/hyperspace";
      inputs.nixpkgs.follows = "unstable";
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
      url = "github:nix-community/home-manager/release-21.05";
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

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "master";
    };

    flake-utils = {
      url = github:numtide/flake-utils;
      inputs.nixpkgs.follows = "master";
    };

    neovim = {
      url = "github:neovim/neovim/d67dcaba02d76fe92ba818dde7b672fe6956a100?dir=contrib";
      inputs.nixpkgs.follows = "unstable";
      inputs.flake-utils.follows = "flake-utils";
    };

    neovitality = {
      url = "github:vi-tality/neovitality";
      inputs.nixpkgs.follows = "master";
      inputs.flake-utils.follows = "flake-utils";
      inputs.naersk.follows = "naersk";
      inputs.rnix-lsp.follows = "rnix-lsp";
      inputs.clojure-lsp-flake.inputs.nixpkgs.follows = "master";
      inputs.clojure-lsp-flake.inputs.flake-utils.follows = "flake-utils";
      inputs.neovim.follows = "neovim";
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
      inputs.nixpkgs.follows = "master";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "master";
    };

    nix-fast-syntax-highlighting = {
      url = "github:zdharma/fast-syntax-highlighting";
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
    , master
    , nixpkgs
    , rust-overlay
    , home-manager
    , emacs-overlay
    , nix-doom-emacs
    , sops-nix
    , deploy-rs
    , rust-filehost
    , mailserver
    , mutt-colors-solarized
    , neovitality
    , vendor-reset
    , construct
    , hyperspace
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
        hyperspace.nixosModules.hyperspace
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
            imports = hmImports ++ [ (./. + "/hosts/${hostname}.hm.nix" ) ];
          };
        })
      ]);
      overlays = [
        stable-pkgs
        emacs-overlay.overlay
        construct.overlay
        (final: prev: {
          hls = inputs.hls.defaultPackage.${system};
        })

        # stolen from git@github.com:bqv/nixrc.git 
        #(final: prev: {
          #riot-web = prev.element-web;
          #matrix-construct = (prev.callPackage "${inputs.construct}/default.nix" { pkgs = prev; });
        #})

        (final: prev: {
          inherit (deploy-rs.packages.${system}) deploy-rs;
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
              cmakeFlags = prevAttrs.cmakeFlags ++ ["-DUSE_SYS_OPENCL=ON" "-DUSE_SYS_OPENCL=ON"];
            }
          );
        }
        )
        (final: prev: {
          inherit (unstable-pkgs) manix maim nextcloud21 nix-du tailscale zerotierone zsa-udev-rules wally-cli rust-cbindgen discord alacritty linuxPackages_5_11 imagemagick hyperspace-cli bottom android-studio exodus innernet thunderbird rocm-device-libs rocm-opencl-icd rocm-opencl-runtime rocm-runtime rocm-smi rocm-thunk rocm-comgr rocm-cmake;
          unstable = unstable-pkgs;
        })
        (final: prev: {
          lispPackages = prev.lispPackages // {
            cl-webkit2 = prev.lispPackages.cl-webkit2.overrideAttrs (oldAttrs:
            {
              src = prev.fetchFromGitHub {
                owner = "joachifm";
                repo = "cl-webkit";
                rev = "90b1469713265096768fd865e64a0a70292c733d";
                sha256 = "sha256:0lxws342nh553xlk4h5lb78q4ibiwbm2hljd7f55w3csk6z7bi06";
              };
            });
            nyxt = prev.lispPackages.nyxt.overrideAttrs (oldAttrs:
          {
            version = "2.1.1";
            src = prev.fetchFromGitHub {
              owner = "atlas-engineer";
              repo = "nyxt";
              rev = "93a2af10f0b305740db0a3232ecb690cd43791f9";
              sha256 = "sha256-GdTOFu5yIIL9776kfbo+KS1gHH1xNCfZSWF5yHUB9U8=";
            };
          });
        };
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
                      path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${host};
                    };
                  };
                };
              });
          results = map gen_node nodes;
        in
        builtins.foldl' pkgs.lib.mergeAttrs { } (results);

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      packages."${system}" = (stable-pkgs null pkgs);
    };

}

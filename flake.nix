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
      url = "github:NixOS/nixpkgs/release-20.09";
    };

    naersk = {
      url = github:nmattia/naersk;
      inputs.nixpkgs.follows = "master";
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
      url = "github:nix-community/home-manager/release-20.09";
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

    construct.url = "github:matrix-construct/construct";

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
    , ...
    }:
    let
      inherit (nixpkgs) lib;
      inherit (lib) recursiveUpdate;
      system = "x86_64-linux";
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
      linux_kernel = unstable-pkgs.linuxPackages_5_11.kernel;



      unstable-pkgs = (utils.pkgImport master [ stable-pkgs ]);
      nixosModules = (hostname: [
        construct.nixosModules.matrix-construct
        mailserver.nixosModule
        (import "${master}/nixos/modules/hardware/keyboard/zsa.nix")
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
        construct.overlay
        (final: prev: {
          hls = inputs.hls.defaultPackage.${system};
        })
        # stolen from git@github.com:bqv/nixrc.git 
        #(final: prev: {
          #riot-web = prev.element-web;
          #matrix-construct = (prev.callPackage "${inputs.construct}/default.nix" { pkgs = prev; });
        #})
        # wait for ATI driver to get fixed
        #(final: prev: {
          #linuxPackagesFor = kernel:
            #(unstable-pkgs.linuxPackagesFor kernel).extend (_: _: { ati_drivers_x11 = null; });

          #latest_kernel = unstable-pkgs.linuxPackages_5_11;
          #vendor-reset = unstable-pkgs.stdenv.mkDerivation rec {
            #pname = "vendor-reset";
            #name = "${pname}-${linux_kernel.version}-${version}";
            #version = "0.1.1";
            #src = vendor-reset;
            #hardeningDisable = [ "pic" ];
            ##enableParallelBuilding = true;
            #nativeBuildInputs = linux_kernel.moduleBuildDependencies;
            #makeFlags = [
              #"KVER=${linux_kernel.modDirVersion}"
              #"KDIR=${linux_kernel.dev}/lib/modules/${linux_kernel.modDirVersion}/build/"
              #"INSTALL_MOD_PATH=$(out)"
            #];
          #};
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
        (final: prev: {
          inherit (unstable-pkgs) manix nyxt maim nextcloud21 nix-du tailscale zerotierone zsa-udev-rules wally-cli rust-cbindgen discord alacritty linuxPackages_5_11;
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
              ip_addr = "100.87.232.34";
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

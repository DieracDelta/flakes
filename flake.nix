{

  description = "A highly awesome system configuration.";

  /*note that I'm aware that flake is true by default. However,*/
  /*I'm sitting on the side of making the flake more explicit */
  /*since I'm easily confused .... */
  inputs = {
    nixpkgs-head.url = "nixpkgs/master";
    nixpkgs.url = "nixpkgs/release-20.09";
    master.url = "nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-20.09";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mailserver =
    {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs-head";
      flake = true;
    };
     # Solarized mutt colorschemes.
    mutt-colors-solarized = {
      url = "github:altercation/mutt-colors-solarized";
      flake = false;
    };
    neovim-nightly-overlay =
    {
        url = "github:nix-community/neovim-nightly-overlay";
        flake = true;
        inputs.nixpkgs.follows = "nixpkgs-head";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs-head";
    };

    nyxt-overlay = {
      url = "github:atlas-engineer/nyxt";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs-head";
    };


    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-doom-emacs = {
      url = "github:vlaci/nix-doom-emacs";
      /*url = "github:vlaci/nix-doom-emacs/fix-gccemacs";*/
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
    };

    gytis-overlay = {
      url = "github:gytis-ivaskevicius/nixfiles";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs-head";
      inputs.master.follows = "nixpkgs-head";
    };

    /*TODO figure out how this works...*/
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs-head";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs-head";
    };

    nix-dram = {
      url = "github:dramforever/nix-dram";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs-head";
    };

    nix-fast-syntax-highlighting = {
      url = "github:zdharma/fast-syntax-highlighting";
      flake = false;
      inputs.nixpkgs.follows = "nixpkgs-head";
    };

    nix-zsh-shell-integration = {
      url = "github:chisui/zsh-nix-shell";
      flake = false;
      inputs.nixpkgs.follows = "nixpkgs-head";
    };

    rust-filehost = {
      url = "github:DieracDelta/filehost_rust";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs-head";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs-head,
      nixpkgs,
      rust-overlay,
      neovim-nightly-overlay,
      home-manager,
      nyxt-overlay,
      emacs-overlay,
      nix-doom-emacs,
      gytis-overlay,
      sops-nix,
      nix-dram,
      deploy-rs,
      rust-filehost,
      mailserver,
      mutt-colors-solarized,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      inherit (lib) recursiveUpdate;
      system = "x86_64-linux";
      /*final -> prev -> pkgs*/
      stable-pkgs = import ./overlays;

      utils = import ./utility-functions.nix {
        inherit lib system pkgs inputs self;
        nixosModules = nixosModules;
      };


      pkgs = (utils.pkgImport nixpkgs overlays);

      hmImports = [
        inputs.nix-doom-emacs.hmModule
        ./home/home.nix
        /*./hosts/laptop.nix*/
        /*{isHomeManager = true;})*/
      ];



      unstable-pkgs = (utils.pkgImport nixpkgs-head [ stable-pkgs ]);
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
        neovim-nightly-overlay.overlay
        stable-pkgs
        emacs-overlay.overlay
        gytis-overlay.overlay
        nyxt-overlay.overlay

        (final: prev: {
          inherit (nix-dram.packages.${system}) nix-search-pretty;
          inherit (deploy-rs.packages.${system}) deploy-rs;
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
          nixUnstable = prev.nixUnstable.overrideAttrs (old: {
            patches = [
              (prev.fetchpatch {
                url = "https://raw.githubusercontent.com/dramforever/nix-dram/main/nix-patches/nix-search-meta.patch";
                sha256 = "sha256-MW9Qc4MZ1tYlSxunxKVCnDLJ7+LMY/JynMIrtp8lBlI=";
              })
            ];
          });

        })


        (final: prev: {
          inherit (unstable-pkgs) manix alacritty nyxt maim nextcloud20 nix-du tailscale zerotierone ;
          unstable = unstable-pkgs;
        })
      ];

    in
    {


      /*TODO: I should probably make this more involved but it's fine for now..*/
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

      devShell.${system} = pkgs.mkShell {
        # imports all files ending in .asc/.gpg and sets $SOPS_PGP_FP.
        sopsPGPKeyDirs = [
          "./secrets"
        ];
        nativeBuildInputs = [
          (pkgs.callPackage sops-nix { }).sops-pgp-hook
        ];
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
      deploy.nodes = {
        laptop = {
          hostname = "100.100.105.124";
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.laptop;
            };
          };
        };
        desktop = {
          hostname = "100.107.190.11";
          fastConnection = true;
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.desktop;
            };
          };
        };
        oracle_vps_1 = {
          hostname = "129.213.62.243";
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.oracle_vps_1;
            };
          };
        };
        oracle_vps_2 = {
          hostname = "150.136.52.94";
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.oracle_vps_2;
            };
          };
        };
      };
      # This is highly advised, and will prevent many possible mistakes
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      packages."${system}" = (stable-pkgs null pkgs);
    };

}

{

  description = "A highly awesome system configuration.";

  /*note that I'm aware that flake is true by default. However,*/
  /*I'm sitting on the side of making the flake more explicit */
  /*since I'm easily confused .... */
  inputs = {
    master.url = "nixpkgs/master";
    nixpkgs.url = "nixpkgs/release-20.09";
    home-manager = {
      url = "github:nix-community/home-manager/release-20.09";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mailserver =
    {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "master";
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
        inputs.nixpkgs.follows = "master";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      flake = true;
      inputs.nixpkgs.follows = "master";
    };

    #nyxt-overlay = {
      #url = "github:atlas-engineer/nyxt";
      #flake = true;
      #inputs.nixpkgs.follows = "master";
    #};


    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      flake = true;
      inputs.nixpkgs.follows = "master";
    };

    nix-doom-emacs = {
      url = "github:vlaci/nix-doom-emacs";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
    };

    gytis-overlay = {
      url = "github:gytis-ivaskevicius/nixfiles";
      flake = true;
      inputs.nixpkgs.follows = "master";
      inputs.master.follows = "master";
    };

    /*TODO figure out how this works...*/
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      flake = true;
      inputs.nixpkgs.follows = "master";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      flake = true;
      inputs.nixpkgs.follows = "master";
    };

    nix-dram = {
      url = "github:dramforever/nix-dram";
      flake = true;
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
      flake = true;
      inputs.nixpkgs.follows = "master";
    };
  };

  outputs =
    inputs@{
      self,
      master,
      nixpkgs,
      rust-overlay,
      neovim-nightly-overlay,
      home-manager,
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
      nixosModules = (hostname: [
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
        neovim-nightly-overlay.overlay
        stable-pkgs
        emacs-overlay.overlay
        gytis-overlay.overlay

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
          inherit (unstable-pkgs) manix alacritty nyxt maim nextcloud21 nix-du tailscale zerotierone zsa-udev-rules wally-cli;
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
            (_node@{ip_addr, host, ...}:
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
          builtins.foldl' pkgs.lib.mergeAttrs {} (results);

      # This is highly advised, and will prevent many possible mistakes
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      packages."${system}" = (stable-pkgs null pkgs);
    };

}

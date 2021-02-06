{

  description = "A highly awesome system configuration.";

  /*note that I'm aware that flake is true by default. However,*/
  /*I'm sitting on the side of making the flake more explicit */
  /*since I'm easily confused .... */
  inputs = {
    nixpkgs-head.url = "nixpkgs/master";
    nixpkgs.url = "nixpkgs/release-20.09";
    home-manager = {
      url = "github:nix-community/home-manager/release-20.09";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    /*not used right now, but once I get a router that I control....*/
    /*mailserver = { url = "gitlab:simple-nixos-mailserver/nixos-mailserver"; flake = true; };*/
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
    };

    /*deploy-rs = {*/
    /*url = "github:serokell/deploy-rs";*/
    /*flake = true;*/
    /*inputs.nixpkgs.follows = "nixpkgs-head";*/
    /*[>inputs.nixpkgs.follows = "nixpkgs-head";<]*/
    /*};*/

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


  };

  outputs = inputs@{ self, nixpkgs-head, nixpkgs, rust-overlay, neovim-nightly-overlay, home-manager, nyxt-overlay, emacs-overlay, nix-doom-emacs, gytis-overlay, sops-nix, nix-dram, ... }:
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
        ./hosts/shared/home.nix
      ];



      unstable-pkgs = (utils.pkgImport nixpkgs-head [ stable-pkgs ]);
      nixosModules = [
        sops-nix.nixosModules.sops
        /* for hardware*/
        nixpkgs.nixosModules.notDetected
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jrestivo = {
            imports = hmImports;
          };
        }
      ];
      overlays = [
        neovim-nightly-overlay.overlay
        stable-pkgs
        emacs-overlay.overlay
        gytis-overlay.overlay
        nyxt-overlay.overlay

        (final: prev: {
          inherit (nix-dram.packages.${system}) nix-search-pretty;
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
          inherit (unstable-pkgs) manix alacritty nyxt maim nextcloud20 nix-du tailscale;
          unstable = unstable-pkgs;
        })
      ];

    in
    {

      /*I should probably make this more involved but it's fine for now..*/
      homeConfigurations = {
        jrestivo =
          home-manager.lib.homeManagerConfiguration {
            inherit system ;
            homeDirectory = /home/jrestivo;
            username = "jrestivo";
            configuration = {pkgs, ...} : {
              imports = hmImports;
              nixpkgs.overlays = overlays;
            };
          };
      };

      /*very simply get all the stuff in hosts/directory to provide as outputs*/
      nixosConfigurations =
        let
          dirs = lib.filterAttrs (name: fileType: (fileType == "regular") && (lib.hasSuffix ".nix" name)) (builtins.readDir ./hosts);
          fullyQualifiedDirs = (lib.mapAttrsToList (name: _v: ./. + (lib.concatStrings [ "/hosts/" name ])) dirs);
        in
        utils.buildNixosConfigurations fullyQualifiedDirs;

      packages."${system}" = (stable-pkgs null pkgs);
    };
}

{

  description = "A highly awesome system configuration.";


  /*note that I'm aware that flake is true by default. However,*/
  /*I'm sitting on the side of making the flake more clean .... */
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

    /*doesn't work.. not sure why */
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

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs-head";
      /*inputs.nixpkgs.follows = "nixpkgs-head";*/
    };

  };

  outputs = inputs@{ self, nixpkgs-head, nixpkgs, rust-overlay, neovim-nightly-overlay, home-manager, nyxt-overlay, emacs-overlay, nix-doom-emacs, gytis-overlay, deploy-rs, ... }:
    let
      inherit (nixpkgs) lib;
      inherit (lib) recursiveUpdate;
      system = "x86_64-linux";
      /*final -> prev -> pkgs*/
      stable-pkgs = import ./overlays;

      utils = import ./utility-functions.nix {
        inherit lib system pkgs inputs self;
        nixosModules = self.nixosModules;
      };


      pkgs = (utils.pkgImport nixpkgs self.overlays);
      unstable-pkgs = (utils.pkgImport nixpkgs-head [ stable-pkgs ]);
    in
    {


      nixosModules = [
        nixpkgs.nixosModules.notDetected
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jrestivo = {
            imports = [
              inputs.nix-doom-emacs.hmModule
              ./hosts/shared/home.nix
            ];
          };
        }
      ];


      /*very simply get all the stuff in hosts/directory to provide as outputs*/
      nixosConfigurations =
        let
          dirs = lib.filterAttrs (name: fileType: (fileType == "regular") && (lib.hasSuffix ".nix" name)) (builtins.readDir ./hosts);
          fullyQualifiedDirs = (lib.mapAttrsToList (name: _v: ./. + (lib.concatStrings [ "/hosts/" name ])) dirs);
        in
        utils.buildNixosConfigurations fullyQualifiedDirs;

      overlays = [
        neovim-nightly-overlay.overlay
        stable-pkgs
        emacs-overlay.overlay
        gytis-overlay.overlay

        (final: prev: {
          inherit (unstable-pkgs) manix alacritty nyxt maim nextcloud20;
          unstable = unstable-pkgs;
        })
      ];

      packages."${system}" = (stable-pkgs null pkgs);
    };
}

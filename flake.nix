{

  description = "A highly awesome system configuration.";


  inputs = {
    nixpkgs_head.url = "nixpkgs/master";
    nixpkgs_stable.url = "nixpkgs/release-20.09";
    home = {
      url = "github:nix-community/home-manager/release-20.09";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs_stable";
    };
    /*not used right now*/
    /*mailserver = { url = "gitlab:simple-nixos-mailserver/nixos-mailserver"; flake = true; };*/
    neovim-nightly-overlay =
    {
      url = "github:nix-community/neovim-nightly-overlay";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs_head";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs_head";
    };
    /*doesn't work.. not sure why : /*/
    /*nyxt-pkg = {*/
      /*url = "github:atlas-engineer/nyxt";*/
      /*flake = true;*/
      /*follows = "master";*/
    /*};*/
    /*these give me a infinite recursion error. Not obvious why...*/
    /*doom-emacs.url = "github:hlissner/doom-emacs/f7293fb67ef701244a421fd3bfc04b8e12689edc";*/
    /*doom-emacs.flake = false;*/
    /*nix-doom-emacs.url = "github:vlaci/nix-doom-emacs";*/
    /*nix-doom-emacs.inputs.doom-emacs.follows = "doom-emacs";*/
  };

  outputs = inputs@{ self, ... }:
    let
    inherit (self.inputs.nixpkgs_stable) lib;
  inherit (lib) recursiveUpdate;
  inherit (builtins) readDir;
  inherit (utils) pathsToImportedAttrs recImport;
  utils = import ./utility-functions.nix { inherit lib; };
  system = "x86_64-linux";


  pkgImport = pkgs:
    import pkgs {
      inherit system;
      config = { allowUnfree = true; };
    };

  unstable-pkgs = pkgImport self.inputs.nixpkgs_head;
  pkgset = {

    inherit unstable-pkgs;
    os-pkgs = pkgImport self.inputs.nixpkgs_stable;
    package-overrides = (with unstable-pkgs; [ manix alacritty nyxt ]);

    inputs = self.inputs;
    custom-pkgs = (import ./pkgs);
    custom-overlays = [
      inputs.neovim-nightly-overlay.overlay
    ];
  };
  in with pkgset; {
    nixosConfigurations = import ./hosts
      (recursiveUpdate inputs { inherit lib pkgset system utils; });
    overlay = pkgset.custom-pkgs;
    packages."${system}" = self.overlay;
  };

}

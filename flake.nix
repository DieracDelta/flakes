{
  description = "A highly awesome system configuration.";

  inputs = {
    master.url = "nixpkgs/master";
    nixos.url = "nixpkgs/release-20.09";
    home.url = "github:nix-community/home-manager/release-20.09";
    firefox  = {
      url = "github:colemickens/flake-firefox-nightly";
    };
    firefox.inputs.nixpkgs.follows = "nixos";
  };

  outputs = inputs@{ self, ... }:
    let
    inherit (self.inputs.nixos) lib;
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

  unstable-pkgs = pkgImport self.inputs.master;
  pkgset = {
    inherit unstable-pkgs;
    /*inherit firefox-pkg;*/
    os-pkgs = pkgImport self.inputs.nixos;
    package-overrides = (with unstable-pkgs; [ manix self.inputs.firefox.packages.${system}.firefox-nightly-bin ]);

    inputs = self.inputs;
    firefox = self.inputs.firefox;
    custom-pkgs = import ./pkgs;
  };
  in with pkgset; {
    nixosConfigurations = import ./hosts
      (recursiveUpdate inputs { inherit lib pkgset system utils; });
    overlay = pkgset.custom-pkgs;
    packages."${system}" = self.overlay;
  };
}

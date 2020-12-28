# {
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
#     # not used yet, but good if I need more cutting edge shit
#     nixpkgs-unstable.url = "nixpkgs/master";

#     home-manager.url = "github:nix-community/home-manager/release-20.09";
#     # same version of nixpkgs for home-manager and global
#     # home-manager.inputs.nixpkgs.follows = "nixpkgs";
#   };

#   outputs = { self, nixpkgs, nixpkgs-unstable, home-manager }: {

#     nixosConfigurations.jrestivo = nixpkgs.lib.nixosSystem {
#       system = "x86_64-linux";
#       modules = [
#         # system config
#         #
#         ./configuration.nix
#         #
#         # user config
#         home-manager.nixosModules.home-manager
#         {
#           home-manager.useGlobalPkgs = true;
#           home-manager.useUserPackages = true;
#           home-manager.users.jrestivo = import ./home.nix;
#         }
#       ];
#     };

#   };

# }

{
  description = "A highly awesome system configuration.";

  inputs = {
    master.url = "nixpkgs/master";
    nixos.url = "nixpkgs/release-20.09";
    home.url = "github:nix-community/home-manager/release-20.09";
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
        os-pkgs = pkgImport self.inputs.nixos;
        package-overrides = with unstable-pkgs; [ manix ];
        inputs = self.inputs;
        custom-pkgs = import ./pkgs;
        nix-options = readDir ./nix-options;
      };
    in with pkgset; {
      nixosConfigurations = import ./hosts
        (recursiveUpdate inputs { inherit lib pkgset system utils; });

      overlay = pkgset.custom-pkgs;
      packages."${system}" = self.overlay;

      nixosModules = (recImport pkgset.nix-options);
    };
}

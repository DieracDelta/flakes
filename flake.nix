{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
    # not used yet, but good if I need more cutting edge shit
    nixpkgs-unstable.url = "nixpkgs/master";

    home-manager.url = "github:nix-community/home-manager/release-20.09";
    # same version of nixpkgs for home-manager and global
    # home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager }: {

    nixosConfigurations.jrestivo = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # system config
        #
        ./configuration.nix
        #
        # user config
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jrestivo = import ./home.nix;
        }
      ];
    };

  };

}

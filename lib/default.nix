# Platform-specific configuration builders
# Usage in flake.nix:
#   myLib = import ./lib { inherit inputs ... };
#   nixosConfigurations = myLib.x86_64-linux.buildNixosConfigurations [ ... ];
{ inputs }:
let
  inherit (inputs.nixpkgs-unpatched) lib;
in
{
  # x86_64-linux: AMD Ryzen optimized (znver3, CUDA)
  x86_64-linux = import ./x86_64-linux.nix {
    inherit lib inputs;
    inherit (inputs)
      self
      nixpkgs-stable
      nixpkgs-master
      home-manager
      quadlet-nix
      ;
    nixpkgs = inputs.nixpkgs;
    overlays = import ../overlays { inherit inputs; };
  };

  # aarch64-linux: ARM NixOS (Oracle Cloud, etc.)
  aarch64-linux = import ./aarch64-linux.nix {
    inherit lib inputs;
    inherit (inputs) self nixpkgs-unpatched home-manager;
  };

  # aarch64-darwin: macOS on Apple Silicon
  aarch64-darwin = import ./aarch64-darwin.nix {
    inherit lib inputs;
    inherit (inputs)
      self
      nixpkgs-unpatched
      darwin
      home-manager
      ;
  };
}

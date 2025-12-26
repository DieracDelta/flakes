# Overlay aggregator
# Usage in flake.nix:
#   overlays = import ./overlays { inherit inputs; }
{ inputs }:
let
  # Simple overlays that don't need inputs
  stdenv = import ./stdenv.nix;
  haskell = import ./haskell.nix;
  zig = import ./zig.nix;
  rust = import ./rust.nix;
  python = import ./python.nix;
  packages = import ./packages.nix;

  # Overlays that need flake inputs
  external = import ./external.nix {
    inherit (inputs) nix my-nvim nixpkgs-master;
  };
in
[
  # Order matters: stdenv should be first since other overlays depend on it
  stdenv
  haskell
  zig
  rust
  python
  packages
  external
  inputs.comfyui-nix.overlays.default
]

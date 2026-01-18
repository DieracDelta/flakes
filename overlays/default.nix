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
  packages = import ./packages.nix { };

  # Overlays that need flake inputs
  external = import ./external.nix {
    inherit (inputs) nix my-nvim nixpkgs-master;
  };

  # Actual Budget with base path support
  actual = import ./actual.nix {
    actual-src = inputs.actual-src;
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
  actual
  inputs.comfyui-nix.overlays.default
]

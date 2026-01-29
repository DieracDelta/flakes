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

  # wger workout/nutrition tracker (local development)
  wger = import ./wger.nix {
    wger-src = inputs.wger;
    wger-react-src = inputs.wger-react;
  };

  # Custom tmux gruvbox themes (darwin=green, arm=red, x86=gruvbox)
  tmux-gruvbox-themes = import ./tmux-gruvbox-themes.nix;

  # Actual Budget with base path support (fetches from DieracDelta/actual fork)
  actual = import ./actual.nix;

  # Taskwarrior Web UI (from GitHub)
  taskwarrior-web = import ./taskwarrior-web.nix;

  # Tmux resurrect and continuum (latest versions)
  tmux-resurrect-continuum = import ./tmux-resurrect-continuum.nix;
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
  tmux-gruvbox-themes
  actual
  taskwarrior-web
  tmux-resurrect-continuum
  wger
  inputs.comfyui-nix.overlays.default
]

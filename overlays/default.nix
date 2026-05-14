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
  mcpRemote = import ./mcp-remote.nix;

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

  # tmux revive replacement (LLM-aware save/restore)
  tmux-revive-llms = import ./tmux-revive-llms.nix {
    tmux-revive-llms = inputs.tmux-revive-llms;
  };

  # Actual Budget with base path support (fetches from DieracDelta/actual fork)
  actual = import ./actual.nix;

  # Taskwarrior Web UI (from GitHub)
  taskwarrior-web = import ./taskwarrior-web.nix;

  tdf = import ./tdf.nix;

  # Tmux resurrect and continuum (latest versions)
  tmux-resurrect-continuum = import ./tmux-resurrect-continuum.nix;

  # Rotki portfolio tracker (local premium, no cloud)
  rotki = import ./rotki.nix {
    rotki-src = inputs.rotki;
  };

  # Tirith terminal security (command analysis before execution)
  tirith = import ./tirith.nix {
    tirith-src = inputs.tirith;
  };

  # Amp CLI (Sourcegraph coding agent) — pinned to latest npm release
  amp-cli = import ./amp-cli.nix;

  # RAPIDS GPU computing stack for cuML (GPU clustering)
  rapids = import ./rapids.nix { };

  # Plane project management (self-hosted)
  plane = import ./plane {
    plane-mcp-server-src = inputs.plane-mcp-server-src;
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
  mcpRemote
  tmux-gruvbox-themes
  tmux-revive-llms
  actual
  taskwarrior-web
  tdf
  tmux-resurrect-continuum
  wger
  inputs.comfyui-nix.overlays.default
  inputs.caldav-calendar-web.overlays.default
  rotki
  tirith
  rapids
  amp-cli
  plane
  # inputs.nix-btm.overlays.default
  inputs.entire-cli.overlays.default
  inputs.claude-code-nix.overlays.default
  # Local path overlay wins so desktop can track /home/jrestivo/dev/claude-code-nix directly.
  inputs.claude-code-nix-local.overlays.default
  inputs.hermes-agent.overlays.default
  inputs.codex-nix.overlays.default
]

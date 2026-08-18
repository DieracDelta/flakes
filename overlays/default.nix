# Overlay aggregator
# Usage in flake.nix:
#   overlays = import ./overlays { inherit inputs; }
{ inputs }:
let
  # Simple overlays that don't need inputs
  disable-tests = import ./disable-tests.nix;
  nixpkgs-fixes = import ./nixpkgs-fixes.nix;
  zig = import ./zig.nix;
  rust = import ./rust.nix;
  nodejs = import ./nodejs.nix;
  ai-agent-tools = import ./ai-agent-tools.nix;
  packages = import ./packages.nix { };
  rmux = import ./rmux.nix;
  mcpRemote = import ./mcp-remote.nix;
  pi = import ./pi.nix;

  # Overlays that need flake inputs
  external = import ./external.nix {
    inherit (inputs) my-nvim;
  };

  caldav-calendar-web = import ./caldav-calendar-web.nix {
    src = inputs.caldav-calendar-web;
  };

  psi-coding-agent = import ./psi-coding-agent.nix {
    src = inputs.psi-coding-agent;
    gitCommit = inputs.psi-coding-agent.shortRev or "unknown";
  };

  shapebpf = import ./shapebpf.nix {
    inherit (inputs) shapebpf;
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

  tdf = import ./tdf.nix;

  # Tmux resurrect and continuum (latest versions)
  tmux-resurrect-continuum = import ./tmux-resurrect-continuum.nix;

  # Rotki portfolio tracker (local premium, no cloud)
  rotki = import ./rotki.nix {
    rotki-src = inputs.rotki;
  };

  # RAPIDS GPU computing stack for cuML (GPU clustering)
  rapids = import ./rapids.nix { };

  # Plane project management (self-hosted)
  plane = import ./plane {
    plane-mcp-server-src = inputs.plane-mcp-server-src;
  };

  # Repowise codebase intelligence MCP server
  repowise = import ./repowise.nix {
    repowise-src = inputs.repowise-src;
  };

  # Octo-Fiesta Subsonic proxy for WRhythm/Navidrome testing
  octo-fiesta = import ./octo-fiesta.nix {
    octo-fiesta-src = inputs.octo-fiesta-src;
  };

  # Jitsi Meet with Olm/E2EE dependency removed.
  jitsi = import ./jitsi.nix;

  # Jitsi Skynet AI services
  skynet = import ./skynet.nix;

  # Native Pijul flake input support, built against the selected Nix package.
  nix-plugin-pijul = import ./nix-plugin-pijul.nix;
in
[
  # Temporary local policy: suppress standard check/install-check phases while
  # retaining every package-specific test declaration for future triage. This
  # must precede overlays that construct language-specific package scopes.
  disable-tests
  nixpkgs-fixes
  inputs.nix.overlays.default
  zig
  rust
  nodejs
  ai-agent-tools
  packages
  rmux
  pi
  psi-coding-agent
  shapebpf
  external
  nix-plugin-pijul
  mcpRemote
  tmux-gruvbox-themes
  actual
  taskwarrior-web
  tdf
  tmux-resurrect-continuum
  wger
  caldav-calendar-web
  rotki
  rapids
  plane
  repowise
  octo-fiesta
  jitsi
  skynet
  # inputs.nix-btm.overlays.default
]

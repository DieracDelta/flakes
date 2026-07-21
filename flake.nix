{
  description = "A highly awesome system configuration.";

  inputs = {
    hl.url = "github:pamburus/hl";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unpatched";
    strace_macos.url = "github:Mic92/strace-macos";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager/master";

    my-nvim.url = "github:DieracDelta/vimconfig";

    nix.url = "github:NixOS/nix/2.34.6";

    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unpatched.url = "github:NixOS/nixpkgs/master";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    comfyui-nix.url = "github:utensils/comfyui-nix";

    # wger workout/nutrition tracker (local development)
    wger.url = "path:/home/jrestivo/dev/wger";
    wger.flake = false;
    wger-react.url = "path:/home/jrestivo/dev/wger-react";
    wger-react.flake = false;
    wger-flutter.url = "path:/home/jrestivo/dev/wger-flutter";
    wger-flutter.flake = false;

    # CalDAV calendar web frontend
    caldav-calendar-web.url = "path:/home/jrestivo/dev/webdav_calendar_view";

    # Rotki portfolio tracker (local premium, no cloud)
    rotki.url = "path:/home/jrestivo/dev/rotki";

    # Plane MCP server local development overlay
    plane-mcp-server-src.url = "path:/home/jrestivo/dev/plane-mcp-server";
    plane-mcp-server-src.flake = false;

    # Repowise codebase intelligence MCP server
    repowise-src.url = "github:repowise-dev/repowise/v0.24.0";
    repowise-src.flake = false;

    # Octo-Fiesta Subsonic proxy for WRhythm/Navidrome testing
    octo-fiesta-src.url = "path:/home/jrestivo/dev/octo-fiesta";
    octo-fiesta-src.flake = false;

    # eBPF process monitor
    bpftop.url = "github:DieracDelta/bpftop";

    # Tirith terminal security (local command analysis before execution)
    tirith.url = "github:sheeki03/tirith";
    tirith.flake = false;

    # Entire CLI
    entire-cli.url = "github:DieracDelta/cli";

    # PSI coding agent
    psi-coding-agent.url = "git+ssh://forgejo@office-desktop.tail5ca7.ts.net/jrestivo/psi-coding-agent.git?ref=feature/aggregate-prs-63-55-51-33";

    # eBPF per-process bandwidth shaping daemon
    shapebpf.url = "github:DieracDelta/shapeBPF";

    # Claude Code and Codex
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    # Local Claude Code overlay for faster testing/rollout than the pinned GitHub input
    claude-code-nix-local.url = "path:/home/jrestivo/dev/claude-code-nix";
    codex-nix.url = "github:sadjow/codex-nix";

    # Declarative Postfix/Dovecot/Rspamd mail stack.
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-26.05";
    simple-nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs-unpatched";
  };

  outputs =
    inputs@{
      self,
      nixpkgs-unpatched,
      ...
    }:
    let
      # Apply patches to nixpkgs
      tmp_pkgs = import nixpkgs-unpatched { localSystem = "x86_64-linux"; };
      nixpkgs = tmp_pkgs.applyPatches {
        name = "nixpkgs";
        src = nixpkgs-unpatched;
        patches = [
          ./PATCH_SUNSHINE
          (tmp_pkgs.fetchpatch {
            url = "https://github.com/DieracDelta/nixpkgs/commit/a1d2240eebf50667a42b18c577c6a6f221e23e83.patch";
            hash = "sha256-mnBr3SXqfU4LekbX8v0Pqg2RsUHVijKbokPkUbArW2k=";
          })
        ];
      };

      # Import platform-specific builders
      myLib = import ./lib {
        inputs = inputs // {
          inherit nixpkgs;
        };
      };

      inherit (nixpkgs-unpatched) lib;
    in
    {
      # x86_64-linux NixOS configurations (auto-discovered from hosts/*.nixos.nix)
      nixosConfigurations =
        let
          # Auto-discover x86_64 hosts (excluding nixos-arm)
          x86Dirs = lib.filterAttrs (
            name: fileType:
            (fileType == "regular") && (lib.hasSuffix ".nixos.nix" name) && (name != "nixos-arm.nixos.nix")
          ) (builtins.readDir ./hosts);
          x86Paths = lib.mapAttrsToList (name: _v: ./. + "/hosts/${name}") x86Dirs;
        in
        myLib.x86_64-linux.buildNixosConfigurations x86Paths
        // {
          # ARM NixOS (separate builder, no znver3/CUDA)
          nixos-arm = myLib.aarch64-linux.buildNixosConfiguration "nixos-arm" (
            import ./hosts/nixos-arm.nixos.nix
          );
        };

      # Darwin (macOS) configurations
      darwinConfigurations."jrestivo-4" = myLib.aarch64-darwin.buildDarwinConfiguration "jrestivo-4";

      # Legacy home-manager configuration (standalone)
      homeConfigurations.jrestivo = inputs.home-manager.lib.homeManagerConfiguration {
        system = "x86_64-linux";
        homeDirectory = /home/jrestivo;
        username = "jrestivo";
        configuration =
          { pkgs, ... }:
          {
            imports = [ ./home/home.nix ];
            nixpkgs.overlays = import ./overlays { inherit inputs; };
          };
      };

      # Hydra CI jobs
      hydraJobs.x86_64-linux.desktop = self.nixosConfigurations.desktop.config.system.build.toplevel;

      # Debug outputs
      mymaster = inputs.nixpkgs-master;
      mything = myLib.x86_64-linux.pkgs;
      mything2 = nixpkgs.outPath;
    };
}

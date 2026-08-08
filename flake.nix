{
  description = "A highly awesome system configuration.";

  inputs = {
    hl.url = "github:pamburus/hl";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unpatched";
    strace_macos.url = "github:Mic92/strace-macos";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    my-nvim.url = "github:DieracDelta/vimconfig";
    # Its original nested pin predates fetchCargoVendor's crates.io
    # data-policy User-Agent and deterministically receives HTTP 403. Pin the
    # first compatible post-fix nixpkgs staging commit: current master cannot
    # be followed yet because its new neovim `wasmSupport` override API is not
    # supported by my-nvim's pinned neovim-nightly-overlay.
    my-nvim.inputs.nixpkgs.url = "github:NixOS/nixpkgs/2a0e0baec1c99cdc087c14f83ac6c31c929d14eb";

    nix.url = "github:NixOS/nix/2.35.1";

    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unpatched.url = "github:NixOS/nixpkgs/master";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    # wger workout/nutrition tracker (pinned upstream; dirty local checkouts are preserved separately)
    wger.url = "github:wger-project/wger/e1d70bcc38cd56ae4a254dca1713c404d069f319";
    wger.flake = false;
    wger-react.url = "github:wger-project/react/28f70598160ccfb76c88c04f9bfe2d08ecd482fd";
    wger-react.flake = false;
    wger-flutter.url = "github:wger-project/flutter/2.0.3";
    wger-flutter.flake = false;

    # CalDAV calendar web frontend; pin the clean upstream commit rather than
    # consuming the local checkout (which contains an untracked result link).
    caldav-calendar-web.url = "github:DieracDelta/webdav-cal-simple/fc56170b2a71e1bd7ccf774c3f9b8b81717621de";

    # Rotki portfolio tracker: v1.43.2 local-premium/Cardano/NEAR port in an
    # isolated clean upgrade tree. The original dirty checkout remains intact.
    rotki.url = "path:/home/jrestivo/dev/rotki-1.43.2-upgrade";

    # Plane MCP server (pinned release; the dirty local development checkout is preserved separately)
    plane-mcp-server-src.url = "github:makeplane/plane-mcp-server/96cf4d51d65cfa5e47d10ff7a4a4caba3b7a98d1";
    plane-mcp-server-src.flake = false;

    # Repowise codebase intelligence MCP server
    repowise-src.url = "github:repowise-dev/repowise/v0.39.0";
    repowise-src.flake = false;

    # Octo-Fiesta Subsonic proxy for WRhythm/Navidrome testing
    octo-fiesta-src.url = "github:V1ck3s/octo-fiesta/v0.10";
    octo-fiesta-src.flake = false;

    # eBPF process monitor
    bpftop.url = "github:DieracDelta/bpftop";

    # PSI coding agent
    psi-coding-agent.url = "git+ssh://forgejo@office-desktop.tail5ca7.ts.net/jrestivo/psi-coding-agent.git?ref=feature/aggregate-prs-63-55-51-33";

    # eBPF per-process bandwidth shaping daemon
    shapebpf.url = "github:DieracDelta/shapeBPF";

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
          ./patches/nixpkgs-replace-stdenv-cross-overlays.patch
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

# aarch64-darwin specific utilities
# For macOS on Apple Silicon
{
  lib,
  inputs,
  self,
  nixpkgs-unpatched,
  darwin,
  home-manager,
}:
let
  system = "aarch64-darwin";

  # Darwin-specific overlays
  overlays = [
    (final: prev: {
      strace-macos = inputs.strace_macos.packages.aarch64-darwin.default;
      nix = inputs.nix.packages.aarch64-darwin.default;
      hl = inputs.hl.packages.aarch64-darwin.default;
    })
    (import ../overlays/tmux-search-panes.nix { })
    (import ../overlays/tmux-gruvbox-themes.nix)
    (import ../overlays/tmux-revive-llms.nix { tmux-revive-llms = inputs.tmux-revive-llms; })
    (import ../overlays/tmux-resurrect-continuum.nix)
    (import ../overlays/tirith.nix { tirith-src = inputs.tirith; })
  ];

  pkgImport =
    nixpkgsSrc:
    import nixpkgsSrc {
      inherit system overlays;
      config = {
        allowUnfree = true;
      };
    };

  pkgs = pkgImport nixpkgs-unpatched;

  buildDarwinConfiguration =
    hostName:
    darwin.lib.darwinSystem {
      inherit system;
      modules = [
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-bak";
          home-manager.users.jrestivo = {
            imports = [ ../home/darwin ];
          };
        }
        ../darwin/config.nix
        {
          nixpkgs.pkgs = pkgs;
        }
      ];
    };
in
{
  inherit pkgImport pkgs buildDarwinConfiguration system;
}

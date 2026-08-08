# aarch64-linux specific utilities
# For ARM NixOS (e.g., Oracle Cloud ARM instances)
# No CPU-specific optimizations, no CUDA
{
  lib,
  inputs,
  self,
  nixpkgs-unpatched,
  home-manager,
}:
let
  system = "aarch64-linux";

  # Minimal overlays for ARM - just tmux plugins
  overlays = [
    (import ../overlays/tmux-search-panes.nix { })
    (import ../overlays/tmux-gruvbox-themes.nix)
    (import ../overlays/tmux-resurrect-continuum.nix)
    # inputs.nix-btm.overlays.default
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

  nixosModules = hostname: [
    # OCI image modules (provide fileSystems, boot.loader, etc.)
    "${nixpkgs-unpatched}/nixos/modules/virtualisation/oci-image.nix"
    "${nixpkgs-unpatched}/nixos/modules/virtualisation/oci-options.nix"
    ../custom_modules/sudo.nix
    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-bak";
      home-manager.users.jrestivo = {
        imports = [ (../. + "/hosts/${hostname}.hm.nix") ];
      };
    }
    inputs.bpftop.nixosModules.default
    ../custom_modules/mailserver-no-rspamd.nix
    inputs.simple-nixos-mailserver.nixosModules.default
    # inputs.nix-btm.nixosModules.default
  ];

  buildNixosConfiguration =
    hostName: hostConfig:
    nixpkgs-unpatched.lib.nixosSystem {
      inherit system;
      modules = [
        hostConfig
        {
          networking.hostName = hostName;
          nixpkgs.pkgs = pkgs;
          system.configurationRevision = lib.mkIf (self ? rev) self.rev;
        }
      ]
      ++ (nixosModules hostName);
      specialArgs = {
        inherit system inputs;
      };
    };
in
{
  inherit
    pkgImport
    pkgs
    buildNixosConfiguration
    system
    ;
}

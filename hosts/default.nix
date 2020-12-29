{ lib, pkgset, self, utils, system, ... }:

let
  inherit (builtins) attrValues removeAttrs readDir;
  inherit (lib) filterAttrs hasSuffix mapAttrs' nameValuePair removeSuffix;
  inherit (pkgset) os-pkgs unstable-pkgs custom-pkgs inputs package-overrides;
  inherit (utils) recImport overlay;

  mapFilterAttrs = seive: f: attrs: filterAttrs seive (mapAttrs' f attrs);

  config = hostName:
    lib.nixosSystem {
      inherit system;

      modules = let
        global = {
          networking.hostName = hostName;
          nixpkgs = { pkgs = os-pkgs; };
          nix.nixPath = let path = toString ../.;
          in [ "nixpkgs=${inputs.master}" "nixos=${inputs.nixos}" ];

          nix.package = os-pkgs.nixUnstable;
          nix.extraOptions = ''
            experimental-features = nix-command flakes
          '';

          nix.registry = {
            nixos.flake = inputs.nixos;
            nixflk.flake = self;
            nixpkgs.flake = inputs.master;
          };

          system.configurationRevision = lib.mkIf (self ? rev) self.rev;
        };

        overrides.nixpkgs.overlays =
          [ custom-pkgs (final: prev: { unstable = unstable-pkgs; }) ]
          ++ (map overlay package-overrides);

      in [
        inputs.home.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jrestivo = import ./shared/home.nix;
        }
        (import "${toString ./.}/${hostName}.nix")
        global
        overrides
      ];

      extraArgs = { inherit system; };
    };

  hosts = recImport {
    dir = ./.;
    _import = config;
  };
in hosts

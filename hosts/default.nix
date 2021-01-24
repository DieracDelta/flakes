{ lib, pkgset, self, utils, system, ... }:

let
inherit (builtins) attrValues removeAttrs readDir;
inherit (lib) filterAttrs hasSuffix mapAttrs' nameValuePair removeSuffix;
inherit (pkgset) os-pkgs unstable-pkgs custom-pkgs inputs package-overrides custom-overlays;
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
      in [ "nixpkgs=${inputs.nixpkgs_head}" "nixos=${inputs.nixpkgs_stable}" ];

      nix.package = os-pkgs.nixUnstable;
      nix.extraOptions = ''
        experimental-features = nix-command flakes
        '';

      /*wtf is going on with this*/
      nix.registry = {
        nixos.flake = inputs.nixpkgs_stable;
        nixflk.flake = self;
        nixpkgs.flake = inputs.nixpkgs_head;
      };

      system.configurationRevision = lib.mkIf (self ? rev) self.rev;
    };

  overrides.nixpkgs.overlays =
    [ custom-pkgs (final: prev: { unstable = unstable-pkgs; }) ]
    ++ (map overlay package-overrides)
    ++ custom-overlays;

  in [
    inputs.home.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.jrestivo = import ./shared/home.nix;
    }
  (import "${toString ./.}/${hostName}.nix" )
    global
    overrides
  ];

  extraArgs = { inherit system pkgset; };
};

hosts = recImport {
  dir = ./.;
  _import = config;
};
in hosts

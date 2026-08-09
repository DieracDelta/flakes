# x86_64-linux specific utilities
# Optimized for AMD Ryzen (znver3) with CUDA support
{
  lib,
  inputs,
  self,
  nixpkgs,
  nixpkgs-stable,
  nixpkgs-master,
  overlays,
  home-manager,
  quadlet-nix,
}:
let
  system = "x86_64-linux";
  inherit (lib) removeSuffix;
  inherit (builtins) listToAttrs;
  genAttrs' = values: f: listToAttrs (map f values);

  pkgs = pkgImport nixpkgs overlays;

  pkgImport =
    nixpkgsSrc: overlays:
    import nixpkgsSrc {
      inherit overlays;
      localSystem = {
        system = "x86_64-linux";
        gcc.arch = "znver3";
        gcc.tune = "znver3";
        gcc.abi = "64";
      };
      config = {
        cudaSupport = true;
        cudaCapabilities = [ "8.9" ];
        allowUnfree = true;
        warnUndeclaredOptions = true;
        fetchedSourceNameDefault = "full";
      };
    };

  nixosModules = hostname: [
    (import ../custom_modules)
    inputs.nixpkgs-unpatched.nixosModules.notDetected
    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-bak";
      home-manager.users.jrestivo = {
        imports = [
          ../home/home.nix
          (../. + "/hosts/${hostname}.hm.nix")
        ];
      };
    }
    quadlet-nix.nixosModules.quadlet
    inputs.bpftop.nixosModules.default
    # inputs.nix-btm.nixosModules.default
    inputs.shapebpf.nixosModules.default
  ];

  buildNixosConfigurations =
    paths:
    genAttrs' paths (
      path:
      let
        hostName = removeSuffix ".nixos.nix" (baseNameOf path);
      in
      {
        name = hostName;
        value = lib.nixosSystem {
          inherit system;

          modules =
            let
              global = {
                networking.hostName = hostName;
                nixpkgs = { inherit pkgs; };
                system.configurationRevision = lib.mkIf (self ? rev) self.rev;

                nix = {
                  nixPath =
                    let
                      path = toString ../.;
                    in
                    (lib.mapAttrsToList (name: _v: "${name}=${inputs.${name}}") inputs) ++ [ "repl=${path}/repl.nix" ];
                  # Use upstream nixpkgs for registry so nix run works without custom config
                  registry.nixpkgs.to = lib.mkForce {
                    type = "github";
                    owner = "NixOS";
                    repo = "nixpkgs";
                    ref = "master";
                  };
                };
              };

            in
            [
              (import path)
              global
            ]
            ++ (nixosModules hostName);

          specialArgs = {
            inherit
              system
              inputs
              builtins
              nixpkgs-stable
              nixpkgs-master
              ;
          };
        };
      }
    );
in
{
  inherit
    pkgImport
    pkgs
    buildNixosConfigurations
    system
    ;
}

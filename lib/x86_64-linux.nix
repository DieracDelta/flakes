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
      localSystem = system;

      hostPlatform = {
        system = "x86_64-linux";
        gcc.arch = "znver3";
        gcc.tune = "znver3";
        gcc.abi = "64";
      };
      targetPlatform = {
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
        doCheckByDefault = false;
        replaceStdenv =
          { pkgs }:
          let
            customStdenv =
              stdenv:
              stdenv.override (old: {
                allowedRequisites = null;
                mkDerivationFromStdenv =
                  stdenvSelf:
                  let
                    defaultMkDerivationFromStdenv =
                      stdenv:
                      (import (pkgs.path + "/pkgs/stdenv/generic/make-derivation.nix") pkgs.lib pkgs.config stdenv)
                      .mkDerivation;
                    mkDerivationSuper = (old.mkDerivationFromStdenv or defaultMkDerivationFromStdenv) stdenvSelf;
                  in
                  args:
                  let
                    applyFlags =
                      currentAttrs: flagName: flagsToAdd:
                      let
                        valEnv = if currentAttrs ? env then (currentAttrs.env.${flagName} or "") else "";
                        valTop = if currentAttrs ? ${flagName} then (currentAttrs.${flagName}) else "";
                        combined = lib.concatStringsSep " " (
                          builtins.filter (x: x != "") [
                            (toString valEnv)
                            (toString valTop)
                            flagsToAdd
                          ]
                        );
                      in
                      (builtins.removeAttrs currentAttrs [ flagName ])
                      // {
                        env = (currentAttrs.env or { }) // {
                          ${flagName} = combined;
                        };
                      };

                    processArgs =
                      attrs:
                      let
                        extraCompile = "-pipe";
                        isHeroicIntegration =
                          (attrs.pname or "") == "heroic-epic-integration"
                          || (builtins.match ".*heroic-epic-integration.*" (attrs.name or "") != null);
                        isGalaxyDummyService =
                          (attrs.pname or "") == "galaxy-dummy-service"
                          || (builtins.match ".*galaxy-dummy-service.*" (attrs.name or "") != null);
                        isGhc = (attrs.pname or "") == "ghc" || (builtins.match ".*ghc.*" (attrs.name or "") != null);
                        isSystemd =
                          (attrs.pname or "") == "systemd" || (builtins.match ".*systemd.*" (attrs.name or "") != null);
                        isOVMF = (attrs.pname or "") == "OVMF" || (builtins.match ".*OVMF.*" (attrs.name or "") != null);

                        shouldSkipRelocs = isHeroicIntegration || isGalaxyDummyService || isGhc || isSystemd || isOVMF;

                        extraLink = (
                          if (stdenvSelf.hostPlatform.isLinux or false) && !shouldSkipRelocs then
                            "-Wl,-z,pack-relative-relocs"
                          else
                            ""
                        );

                        attrsWithCompileFlags = applyFlags attrs "NIX_CFLAGS_COMPILE" extraCompile;
                      in
                      applyFlags attrsWithCompileFlags "NIX_CFLAGS_LINK" extraLink;
                  in
                  if builtins.isFunction args then
                    mkDerivationSuper (self: processArgs (args self))
                  else
                    mkDerivationSuper (processArgs args);
              });
          in
          customStdenv pkgs.stdenv;
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

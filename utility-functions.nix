{
  lib,
  self,
  inputs,
  system,
  pkgs,
  nixosModules,
  nixpkgs-stable,
  nixpkgs-master,
  ...
}:
let
  inherit (lib) removeSuffix;
  inherit (builtins) listToAttrs;
  genAttrs' = values: f: listToAttrs (map f values);

in
{
  pkgImport =
    pkgs: overlays:
    import pkgs {
      inherit overlays;
      localSystem = "x86_64-linux";

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
        # TODO allowVariants could be interesting
        cudaSupport = true;
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
                      (import (pkgs.path + "/pkgs/stdenv/generic/make-derivation.nix") {
                        inherit (pkgs) lib config;
                      } stdenv).mkDerivation;
                    mkDerivationSuper = (old.mkDerivationFromStdenv or defaultMkDerivationFromStdenv) stdenvSelf;
                  in
                  args:
                  let
                    # Function to apply flags to either env.FLAG or top-level FLAG
                    applyFlags =
                      currentAttrs: flagName: flagsToAdd:
                      let
                        valEnv = if currentAttrs ? env then (currentAttrs.env.${flagName} or "") else "";
                        valTop = if currentAttrs ? ${flagName} then (currentAttrs.${flagName}) else "";
                        # Combine existing env + top-level + new flags
                        combined = lib.concatStringsSep " " (
                          builtins.filter (x: x != "") [
                            (toString valEnv)
                            (toString valTop)
                            flagsToAdd
                          ]
                        );
                      in
                      # ALWAYS put flags in env and remove from top-level.
                      # This avoids conflicts if overrideAttrs later introduces env/structured attrs.
                      # Legacy mkDerivation supports env vars too.
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
                        # (MinGW build)
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

        # RUSTFLAGS = "-C target-cpu=znver3 ";
        # permittedInsecurePackages = [ "nix-2.15.3" ];

        # allowUnsupportedSystem = true;
      };
    };

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
                  # package = pkgs.nixUnstable;
                  nixPath =
                    let
                      path = toString ./.;
                    in
                    (lib.mapAttrsToList (name: _v: "${name}=${inputs.${name}}") inputs) ++ [ "repl=${path}/repl.nix" ];
                  registry =
                    (lib.mapAttrs' (name: _v: lib.nameValuePair name ({ flake = inputs.${name}; })) inputs)
                    // {
                      ${hostName}.flake = self;
                    };
                };
              };

            in
            [
              # this actually imports the specific host file
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
}

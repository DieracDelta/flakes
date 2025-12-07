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

        # RUSTFLAGS = "-C target-cpu=znver3 ";
        # permittedInsecurePackages = [ "nix-2.15.3" ];

        # allowUnsupportedSystem = true;

        replaceStdenv =
          { pkgs }:
          let
            clangStdenv = pkgs.llvmPackages_latest.stdenv;
            moldStdenv = pkgs.stdenvAdapters.useMoldLinker clangStdenv;
            withPackRelativeRelocs =
              stdenv:
              stdenv.override (old: {
                mkDerivationFromStdenv =
                  stdenvSelf:
                  let
                    mkDerivationSuper =
                      (old.mkDerivationFromStdenv or (import (pkgs.outPath + "/pkgs/stdenv/generic/make-derivation.nix") {
                        inherit (pkgs)
                          lib
                          config
                          ;
                      })
                      )
                        stdenvSelf;
                  in
                  args:
                  (mkDerivationSuper args).overrideAttrs (prevAttrs: {
                    NIX_CFLAGS_LINK = toString (prevAttrs.NIX_CFLAGS_LINK or "") + " -Wl,-z,pack-relative-relocs,-pipe";
                  });
              });
          in
          withPackRelativeRelocs moldStdenv;
        # replaceStdenv = ({ pkgs }: pkgs.clangStdenv);
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

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
        allowUnsupportedSystem = true;

        # RUSTFLAGS = "-C target-cpu=znver3 ";
        # permittedInsecurePackages = [ "nix-2.15.3" ];

        # allowUnsupportedSystem = true;

        replaceStdenv =
          { pkgs }:
          let
            clangStdenv = pkgs.llvmPackages_latest.stdenv;

            customStdenv =
              stdenv:
              let
                bintools = stdenv.cc.bintools.override {
                  extraBuildCommands = ''
                    wrap ld.mold ${pkgs.path}/pkgs/build-support/bintools-wrapper/ld-wrapper.sh ${pkgs.buildPackages.mold}/bin/ld.mold
                    wrap ${stdenv.cc.bintools.targetPrefix}ld.mold ${pkgs.path}/pkgs/build-support/bintools-wrapper/ld-wrapper.sh ${pkgs.buildPackages.mold}/bin/ld.mold
                    wrap ${stdenv.cc.bintools.targetPrefix}ld ${pkgs.path}/pkgs/build-support/bintools-wrapper/ld-wrapper.sh ${pkgs.buildPackages.mold}/bin/ld.mold
                  '';
                };
              in
              stdenv.override (old: {
                allowedRequisites = null;
                cc = stdenv.cc.override { inherit bintools; };

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
                  (mkDerivationSuper args).overrideAttrs (
                    prevAttrs:
                    if (prevAttrs.__structuredAttrs or false) || (prevAttrs ? env.NIX_CFLAGS_LINK) then
                      {
                        env = (prevAttrs.env or { }) // {
                          NIX_CFLAGS_LINK =
                            toString (prevAttrs.env.NIX_CFLAGS_LINK or "") + " -fuse-ld=mold -Wl,-z,pack-relative-relocs";
                        };
                      }
                    else
                      {
                        NIX_CFLAGS_LINK =
                          toString (prevAttrs.NIX_CFLAGS_LINK or "") + " -fuse-ld=mold -Wl,-z,pack-relative-relocs";
                      }
                  );
              });
          in
          customStdenv clangStdenv;
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

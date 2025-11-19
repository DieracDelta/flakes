{
  description = "A highly awesome system configuration.";

  inputs = {
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager/master";

    my-nvim.url = "github:DieracDelta/vimconfig";

    nix.url = "github:NixOS/nix/2.32.4";

    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    nixpkgs-master.url = "github:NixOS/nixpkgs/9967182c2d4b41d6e66fe16b547a65697c27601e";

    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    nixpkgs-unpatched.url = "github:NixOS/nixpkgs/9967182c2d4b41d6e66fe16b547a65697c27601e";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs-unpatched,
      nixpkgs-stable,
      nixpkgs-master,
      home-manager,
      darwin,
      my-nvim,
      nix,
      quadlet-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      tmp_pkgs = import nixpkgs-unpatched { localSystem = system; };
      nixpkgs = tmp_pkgs.applyPatches {
        name = "nixpkgs";
        src = nixpkgs-unpatched;
        patches = [
          ./PATCH
          ./PATCH_ZIG
          ./PATCH_SUNSHINE
        ];
      };
      inherit (nixpkgs-unpatched) lib;

      utils = import ./utility-functions.nix {
        inherit
          lib
          system
          pkgs
          inputs
          self
          nixpkgs-stable
          nixpkgs-master
          ;
        nixosModules = nixosModules;
      };
      pkgs = (utils.pkgImport nixpkgs overlays);

      hmImports = [
        ./home/home.nix
      ];
      nixosModules = hostname: [
        (import ./custom_modules)
        nixpkgs-unpatched.nixosModules.notDetected
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jrestivo = {
            imports = hmImports ++ [ (./. + "/hosts/${hostname}.hm.nix") ];
          };
        }
        quadlet-nix.nixosModules.quadlet
      ];

      overlays = [
        (final: prev: {
          haskell = prev.haskell // {
            compiler = prev.haskell.compiler // {
              ghc984 = prev.haskell.compiler.ghc984.override {
                useLLVM = true;
              };
            };
          };
        })
        (
          final: prev:
          let
            inherit (final) lib;
            makeGhcOptions = opts: lib.concatStringsSep " " (map (opt: "--ghc-option=${opt}") opts);
          in
          {
            haskell = prev.haskell // {
              packages = prev.haskell.packages // {
                ghc984 = prev.haskell.packages.ghc984.override {
                  overrides = hfinal: hprev: {
                    mkDerivation =
                      args:
                      hprev.mkDerivation (
                        args
                        // {
                          configureFlags = (args.configureFlags or [ ]) ++ [
                            (makeGhcOptions [
                              "-fllvm"
                              "-optc=-march=znver3"
                              "-optlo=-mcpu=znver3"
                              "-O2"
                            ])
                          ];
                        }
                      );
                  };
                };
              };
            };
          }
        )
        (final: prev: {
          nix = nix.packages.x86_64-linux.default;
          makeRustPlatform =
            final.callPackage "${nixpkgs}/pkgs/development/compilers/rust/make-rust-platform.nix"
              {
                GLOBAL_RUSTFLAGS = "-C target-cpu=znver3 ";
              };
          zig_0_13 = prev.zig_0_13.overrideAttrs (finalAttrs: {
            passthru = finalAttrs.passthru // {
              hook = final.callPackage "${nixpkgs}/pkgs/development/compilers/zig/hook.nix" {
                zig = final.zig_0_13;
                globalBuildFlags = [ "-Dcpu=znver3" ];
              };
              zig = finalAttrs.finalPackage;
            };
          });
          zig_0_14 = prev.zig_0_14.overrideAttrs (finalAttrs: {
            passthru = finalAttrs.passthru // {
              hook = final.callPackage "${nixpkgs}/pkgs/development/compilers/zig/hook.nix" {
                zig = final.zig_0_14;
                globalBuildFlags = [
                  "-Dcpu=znver3"
                  "-fno-reference-trace"
                ];
              };
              zig = finalAttrs.finalPackage;
            };
          });
          zig_0_15 = prev.zig_0_15.overrideAttrs (finalAttrs: {
            passthru = finalAttrs.passthru // {
              hook = final.callPackage "${nixpkgs}/pkgs/development/compilers/zig/hook.nix" {
                zig = final.zig_0_15;
                globalBuildFlags = [ "-Dcpu=znver3" ];
              };
              zig = finalAttrs.finalPackage;
            };
          });
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (python-final: python-prev: {
              psycopg = python-prev.psycopg.overridePythonAttrs (oldAttrs: {
                doCheck = false;
                propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [ python-final.psycopg-pool ];
              });
              dj-database-url = python-prev.dj-database-url.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
              chromadb = python-prev.chromadb.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
              curl-cffi = python-prev.curl-cffi.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
              django = python-prev.django.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
              granian = python-prev.granian.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
              django-pytest = python-prev.django-pytest.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
              rapidocr-onnxruntime = python-prev.rapidocr-onnxruntime.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
              anyio = python-prev.anyio.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
            })
          ];
          libsecret = prev.libsecret.overrideAttrs (oldAttrs: {
            doCheck = false;
          });
          haskellPackages = prev.haskellPackages.extend (
            hself: hsuper: {
              cryptonite = hsuper.cryptonite.overrideAttrs (oldAttrs: {
                doCheck = false;
              });
              wherefrom-compat = hsuper.wherefrom-compat.overrideAttrs (oldAttrs: {
                doCheck = false;
              });
              xmobar = final.haskell.lib.compose.overrideCabal (drv: {
                enableSeparateBinOutput = false;
              }) hsuper.xmobar;
              cachix = final.haskell.lib.compose.overrideCabal (drv: {
                enableSeparateBinOutput = false;
              }) hsuper.cachix;
              yaml = final.haskell.lib.compose.overrideCabal (drv: {
                enableSeparateBinOutput = false;
              }) hsuper.yaml;
            }
          );
          nvim = my-nvim.defaultPackage.x86_64-linux;
          xmobar = final.haskellPackages.xmobar;
        })
      ];
    in
    {
      homeConfigurations.jrestivo = home-manager.lib.homeManagerConfiguration {
        inherit system;
        homeDirectory = /home/jrestivo;
        username = "jrestivo";
        configuration =
          { pkgs, ... }:
          {
            imports = hmImports;
            nixpkgs.overlays = overlays;
          };
      };

      nixosConfigurations =
        let
          dirs = lib.filterAttrs (
            name: fileType: (fileType == "regular") && (lib.hasSuffix ".nixos.nix" name)
          ) (builtins.readDir ./hosts);
          fullyQualifiedDirs = lib.mapAttrsToList (name: _v: ./. + "/hosts/${name}") dirs;
        in
        utils.buildNixosConfigurations fullyQualifiedDirs;

      darwinConfigurations."jrestivo-4" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jrestivo = {
              imports = [ ./home/darwin ];
            };
          }
          ./darwin/config.nix
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              (final: prev: {
                nvim = my-nvim.defaultPackage.aarch64-darwin;
                nix = inputs.nix.packages.aarch64-darwin.default;
              })
            ];
          }
        ];
      };

      mything = pkgs;
      mything2 = nixpkgs.outPath;
    };
}

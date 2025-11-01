{

  description = "A highly awesome system configuration.";

  inputs = {
    nix = {
      url = "github:NixOS/nix/2.32.1";
    };
    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-unpatched";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unpatched";
    nixpkgs-unpatched = {
      # url = "git+file:///home/jrestivo/dev/nixpkgs";
      # url = "path:/home/jrestivo/nixpkgs";
      # url = "github:NixOS/nixpkgs/master";
      url = "github:NixOS/nixpkgs/master";
    };

    nixpkgs-stable = {
      # url = "path:/home/jrestivo/nixpkgs";
      url = "github:NixOS/nixpkgs/nixos-25.05";
    };

    nixpkgs-master = {
      # url = "path:/home/jrestivo/nixpkgs";
      url = "github:NixOS/nixpkgs/master";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
    };

    my-nvim = {
      url = "github:DieracDelta/vimconfig";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

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
      system_x86 = "x86_64-linux";
      system = system_x86;
      tmp_pkgs = import nixpkgs-unpatched { localSystem = "x86_64-linux"; };
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
      nixosModules = (
        hostname: [
          (import ./custom_modules)
          nixpkgs-unpatched.nixosModules.notDetected
          home-manager.nixosModules.home-manager
          # "${
          #   builtins.fetchGit {
          #     url = "https://github.com/antithesishq/madness.git";
          #     rev = "c22c9c03579b7175d94f63e44ee0e518bb5ccdba";
          #   }
          # }/modules"
          # inputs.nixified-ai.nixosModules.comfyui
          ({
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jrestivo = {
              imports = hmImports ++ [ (./. + "/hosts/${hostname}.hm.nix") ];
            };
          })
          quadlet-nix.nixosModules.quadlet
        ]
      );
      overlays = [
        # inputs.nixified-ai.overlays.comfyui
        # inputs.nixified-ai.overlays.models
        # inputs.nixified-ai.overlays.fetchers
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
                              # "-optlo=-flto"
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
                globalBuildFlags = [
                  "-Dcpu=znver3"
                  # "-flto"
                ];
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
                  # "-flto"
                ];
              };
              zig = finalAttrs.finalPackage;
            };
          });
          zig_0_15 = prev.zig_0_15.overrideAttrs (finalAttrs: {
            passthru = finalAttrs.passthru // {
              hook = final.callPackage "${nixpkgs}/pkgs/development/compilers/zig/hook.nix" {
                zig = final.zig_0_15;
                globalBuildFlags = [
                  "-Dcpu=znver3"
                  # "-flto"
                ];
              };
              zig = finalAttrs.finalPackage;
            };
          });
          # openldap = prev.folly.overrideAttrs (old: {
          #   doCheck = false;
          # });
          # folly = prev.folly.overrideAttrs (old: {
          #   checkPhase = "";
          # });
          # starship = prev.starship.overrideAttrs (old: {
          #   doCheck = false;
          # });
          # libsecret = prev.libsecret.overrideAttrs (old: {
          #   doCheck = false;
          # });
          # notmuch = prev.notmuch.overrideAttrs (old: {
          #   doCheck = false;
          # });
          # libadwaita = prev.libadwaita.overrideAttrs (old: {
          #   doCheck = false;
          # });
          # ibus = nixpkgs-stable.legacyPackages."x86_64-linux".ibus;
          # libqmi = nixpkgs-stable.legacyPackages."x86_64-linux".libqmi;
          # modemmanager = nixpkgs-stable.legacyPackages."x86_64-linux".modemmanager;
          # networkmanager = nixpkgs-stable.legacyPackages."x86_64-linux".networkmanager;
          # pipewire = nixpkgs-stable.legacyPackages."x86_64-linux".pipewire;
          #
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
              # psycopg = python-prev.psycopg.overridePythonAttrs (oldAttrs: {
              #   doCheck = false;
              # });

              anyio = python-prev.anyio.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
            })
          ];
          # xmobar = final.haskell.lib.compose.overrideCabal (drv: {
          #   enableSeparateBinOutput = false;
          # }) prev.haskellPackages.xmobar;
          haskellPackages = prev.haskellPackages.extend (
            hself: hsuper: {
              #     crypton = hsuper.crypton.overrideAttrs (oldAttrs: {
              #       doCheck = false;
              #     });
              #     crypton-x509-validation = hsuper.crypton-x509-validation.overrideAttrs (oldAttrs: {
              #       doCheck = false;
              #     });
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

              # xmobar = hsuper.xmobar.overrideAttrs (oldAttrs: {
              #   enableSeparateBinOutput = false;
              # });

              #
            }
          );
          nvim = my-nvim.defaultPackage.x86_64-linux;
          xmobar = final.haskellPackages.xmobar;
        })
      ];
    in
    {

      homeConfigurations = {
        jrestivo = home-manager.lib.homeManagerConfiguration {
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
      };

      # very simply get all the stuff in hosts/directory to provide as outputs
      nixosConfigurations =
        let
          dirs = lib.filterAttrs (
            name: fileType: (fileType == "regular") && (lib.hasSuffix ".nixos.nix" name)
          ) (builtins.readDir ./hosts);
          fullyQualifiedDirs = (lib.mapAttrsToList (name: _v: ./. + "/hosts/${name}") dirs);
        in
        utils.buildNixosConfigurations fullyQualifiedDirs;

      darwinConfigurations."jrestivo-2" = darwin.lib.darwinSystem {
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
                tdf = prev.tdf.overrideAttrs (
                  finalAttrs: prevAttrs: {
                    pname = "tdf";
                    version = "custom";
                    useFetchCargoVendor = true;
                    src = prev.fetchFromGitHub {
                      owner = "itsjunetime";
                      repo = "tdf";
                      fetchSubmodules = false;
                      rev = "d01da40f13a29371d7a705f822597923dab1a9e7";
                      hash = "sha256-a82m0d1cFi5EwnDrgeZQnsS5ScPdLo/D9NPFN27hvo4=";
                    };
                    nativeBuildInputs = [ final.rustPlatform.bindgenHook ];
                    RUSTC_BOOTSTRAP = true;
                    # cargoHash = lib.fakeHash;
                    cargoDeps = final.rustPlatform.fetchCargoVendor {
                      inherit (finalAttrs) src;
                      name = "${finalAttrs.pname}-${finalAttrs.version}";
                      hash = "sha256-DxD+Zu6e/YkbFP/R0kBHpuj7E9ZJ2aRpF01VQwMAfkU=";
                    };

                  }
                );

              })
            ];
          }
        ];
      };

      mything = pkgs;
      mything2 = nixpkgs.outPath;
    };
}

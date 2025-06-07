{

  description = "A highly awesome system configuration.";

  inputs = {
    nix = {
      url = "github:NixOS/nix/2.28.3";
    };
    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unpatched";
    nixpkgs-unpatched = {
      # url = "git+file:///home/jrestivo/dev/nixpkgs";
      # url = "path:/home/jrestivo/nixpkgs";
      # url = "github:NixOS/nixpkgs/master";
      url = "github:NixOS/nixpkgs/e32e3fcd18f9301cbaa2ac4198a03e0f3e065928";
    };

    nixpkgs-stable = {
      # url = "path:/home/jrestivo/nixpkgs";
      url = "github:NixOS/nixpkgs/nixos-25.05";
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
      home-manager,
      darwin,
      my-nvim,
      nix,
      ...
    }:
    let
      system_x86 = "x86_64-linux";
      system = system_x86;
      tmp_pkgs = import nixpkgs-unpatched { localSystem = "x86_64-linux"; };
      nixpkgs = tmp_pkgs.applyPatches {
        name = "nixpkgs";
        src = nixpkgs-unpatched;
        patches = [ ./PATCH ];
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
          "${
            builtins.fetchGit {
              url = "https://github.com/antithesishq/madness.git";
              rev = "c22c9c03579b7175d94f63e44ee0e518bb5ccdba";
            }
          }/modules"
          inputs.nixified-ai.nixosModules.comfyui
          ({
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jrestivo = {
              imports = hmImports ++ [ (./. + "/hosts/${hostname}.hm.nix") ];
            };
          })
        ]
      );
      overlays = [
        inputs.nixified-ai.overlays.comfyui
        inputs.nixified-ai.overlays.models
        inputs.nixified-ai.overlays.fetchers
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
          makeRustPlatform = (
            final.callPackage "${nixpkgs}/pkgs/development/compilers/rust/make-rust-platform.nix" {
              rustConfig.RUSTFLAGS = "-C target-cpu=znver3 ";
            }
          );
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
              wherefrom-compat = hsuper.wherefrom-compat.overrideAttrs (oldAttrs: {
                doCheck = false;
              });
              xmobar = final.haskell.lib.compose.overrideCabal (drv: {
                enableSeparateBinOutput = false;
              }) hsuper.xmobar;

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
              })
            ];
          }
        ];
      };

      mything = pkgs;
    };
}

{

  description = "A highly awesome system configuration.";

  inputs = {
    nix = {
      url = "github:NixOS/nix/2.28.3";
    };

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs = {
      # url = "path:/home/jrestivo/nixpkgs";
      url = "github:NixOS/nixpkgs/master";
    };

    nixpkgs-stable = {
      # url = "path:/home/jrestivo/nixpkgs";
      url = "github:NixOS/nixpkgs/nixos-24.11";
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
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      darwin,
      my-nvim,
      nix,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      inherit (lib) recursiveUpdate;
      system_x86 = "x86_64-linux";
      system_arm = "aarch64-linux";
      system = system_x86;

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
          nixpkgs.nixosModules.notDetected
          home-manager.nixosModules.home-manager
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
        (final: prev: {
          nix = nix.packages.x86_64-linux.default;
          openldap = prev.folly.overrideAttrs (old: {
            doCheck = false;
          });
          folly = prev.folly.overrideAttrs (old: {
            checkPhase = "";
          });
          starship = prev.starship.overrideAttrs (old: {
            doCheck = false;
          });
          libsecret = prev.libsecret.overrideAttrs (old: {
            doCheck = false;
          });
          notmuch = prev.notmuch.overrideAttrs (old: {
            doCheck = false;
          });
          libadwaita = prev.libadwaita.overrideAttrs (old: {
            doCheck = false;
          });
          ibus = nixpkgs-stable.legacyPackages."x86_64-linux".ibus;
          libqmi = nixpkgs-stable.legacyPackages."x86_64-linux".libqmi;
          modemmanager = nixpkgs-stable.legacyPackages."x86_64-linux".modemmanager;
          networkmanager = nixpkgs-stable.legacyPackages."x86_64-linux".networkmanager;
          pipewire = nixpkgs-stable.legacyPackages."x86_64-linux".pipewire;
          # /Users/jrestivo/dev/nixpkgs/pkgs/by-name/td/tdf/
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (python-final: python-prev: {
              numpy = python-prev.numpy.overridePythonAttrs (oldAttrs: {
                doCheck = false;
              });
            })
          ];
          haskellPackages = prev.haskellPackages.extend (
            hself: hsuper: {
              crypton = hsuper.crypton.overrideAttrs (oldAttrs: {
                doCheck = false;
              });
              crypton-x509-validation = hsuper.crypton-x509-validation.overrideAttrs (oldAttrs: {
                doCheck = false;
              });
              tls = hsuper.tls.overrideAttrs (oldAttrs: {
                doCheck = false;
              });

            }
          );
          nvim = my-nvim.defaultPackage.x86_64-linux;
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
    };
}

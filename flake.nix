{
  description = "A highly awesome system configuration.";

  inputs = {
    hl.url = "github:pamburus/hl";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unpatched";
    strace_macos.url = "github:Mic92/strace-macos";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager/master";

    my-nvim.url = "github:DieracDelta/vimconfig";

    nix.url = "github:NixOS/nix/2.32.4";

    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unpatched.url = "github:NixOS/nixpkgs/master";

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
        # Global overlay to disable doCheck and doInstallCheck for all derivations
        (final: prev: {
          stdenv = prev.stdenv // {
            mkDerivation =
              fnOrAttrs:
              let
                disableChecks = ''
                  unset doCheck
                  unset doInstallCheck
                '';
                # Prepend disableChecks to a phase, handling string, list, or missing cases
                prependToPhase = phase:
                  if builtins.isList phase then [ disableChecks ] ++ phase
                  else if builtins.isString phase then disableChecks + phase
                  else disableChecks;
                addDisablePhase =
                  attrs:
                  let
                    existingPrePhases = attrs.prePhases or [ ];
                  in
                  attrs // {
                    prePhases =
                      if builtins.elem "disableChecksPhase" existingPrePhases
                      then existingPrePhases
                      else existingPrePhases ++ [ "disableChecksPhase" ];
                    disableChecksPhase = disableChecks;
                    # Also unset in preCheck and preInstallCheck for builders that set these later
                    preCheck = prependToPhase (attrs.preCheck or null);
                    preInstallCheck = prependToPhase (attrs.preInstallCheck or null);
                  };
              in
              if builtins.isFunction fnOrAttrs then
                prev.stdenv.mkDerivation (attrs: addDisablePhase (fnOrAttrs attrs))
              else
                prev.stdenv.mkDerivation (addDisablePhase fnOrAttrs);
          };
        })
        (final: prev: {

          haskell =
            let
              inherit (final) lib;
              makeGhcOptions = opts: lib.concatStringsSep " " (map (opt: "--ghc-option=${opt}") opts);
            in
            prev.haskell
            // {
              # compiler = prev.haskell.compiler // {
              #   ghc9103 = prev.haskell.compiler.ghc9103.override {
              #     useLLVM = true;
              #     # llvmPackages = final.llvmPackages_18;
              #   };
              # };
              # compiler = prev.lib.mapAttrs (
              #   name: drv:
              #   # 1. Check if it is a derivation and supports overrides
              #   if prev.lib.isDerivation drv && drv ? override then
              #     # 2. NAME CHECK: Skip "Binary" distributions (pre-compiled)
              #     #    Source versions (ghc98, ghc910) support useLLVM.
              #     #    Binary versions (ghc984Binary) do not.
              #     if !(prev.lib.hasSuffix "Binary" name) then
              #       drv.override {
              #         useLLVM = true;
              #         # llvmPackages = final.llvmPackages_18;
              #       }
              #     else
              #       drv
              #   else
              #     drv
              # ) prev.haskell.compiler;

              packageOverrides =
                hfinal: hprev:
                prev.lib.composeExtensions (prev.haskell.packageOverrides or (_: _: { })) (hfinal: hprev: {
                  mkDerivation =
                    args:
                    hprev.mkDerivation (
                      args
                      // {
                        configureFlags = (args.configureFlags or [ ]) ++ [
                          (makeGhcOptions [
                            # "-fllvm"
                            "-optc=-march=znver3"
                            "-optlo=-mcpu=znver3"
                            "-O2"
                          ])
                        ];
                      }
                    );
                }) hfinal hprev;
            };

        })
        (
          final: prev:
          let
            customizeZig =
              name: drv:
              let
                extraFlags = if name == "zig_0_14" then [ "-fno-reference-trace" ] else [ ];
                myGlobalFlags = [ "-Dcpu=znver3" ] ++ extraFlags;

                finalZig = drv.overrideAttrs (old: {
                  passthru = old.passthru // {
                    hook = final.callPackage "${prev.path}/pkgs/development/compilers/zig/hook.nix" {
                      zig = finalZig;
                      globalBuildFlags = myGlobalFlags;
                    };
                    zig = finalZig;
                  };
                });
              in
              finalZig;
            zigTargets = [
              "zig_0_13"
              "zig_0_14"
              "zig_0_15"
            ];
            validZigSets = builtins.filter (name: builtins.hasAttr name prev) zigTargets;
          in
          lib.genAttrs validZigSets (name: customizeZig name prev.${name})
        )
        (final: prev: {
          nototools = prev.nototools.overridePythonAttrs (old: {
            dontCheckRuntimeDeps = true;
            catchConflicts = false;
          });

          libp11 = prev.libp11.overrideAttrs (oldAttrs: {
            src = prev.fetchFromGitHub {
              owner = "OpenSC";
              repo = "libp11";
              rev = "${prev.libp11.pname}-${prev.libp11.version}";
              sha256 = "sha256-xH5Ic8HpWB5O2MWXf2A9FUiV10VZajDdPqEVF0Hs6u0=";
            };

          });
          libkate = prev.libkate.overrideAttrs (old: {
            src = final.fetchFromGitLab {
              domain = "gitlab.xiph.org";
              owner = "xiph";
              repo = "kate";
              rev = "kate-0.4.3";
              hash = "sha256-HwDahmjDC+O321Ba7MnHoQdHOFUMpFzaNdLHQeEg11Q=";
            };
          });
          # TODO fix this -- it's very broken and IDK why
          influxdb2 = inputs.nixpkgs-master.legacyPackages.x86_64-linux.influxdb2;
          usbmuxd2 = prev.usbmuxd2.overrideAttrs (oldAttrs: {
            src = prev.fetchFromGitHub {
              owner = "tihmstar";
              repo = "usbmuxd2";
              rev = "2ce399ddbacb110bd5a83a6b8232d42c9a9b6e84";
              hash = "sha256-u7qRKH5y+Q1HnnumjVm3Ce4SlT3YaEVSPUXYOAiFBes=";
              # Leave DotGit so that autoconfigure can read version from git tags
              leaveDotGit = true;
            };
          });
        })
        (final: prev: {
          nix = nix.packages.x86_64-linux.default;
          makeRustPlatform =
            args:
            prev.callPackage "${prev.path}/pkgs/development/compilers/rust/make-rust-platform.nix" {
              GLOBAL_RUSTFLAGS = "-C target-cpu=znver3";
            } args;

          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (python-final: python-prev: {
              # Python packages don't go through our stdenv overlay, so add the phase here
              disableCheckArgs =
                args:
                let
                  existingPrePhases = args.prePhases or [ ];
                in
                args
                // {
                  prePhases =
                    if builtins.elem "disableChecksPhase" existingPrePhases
                    then existingPrePhases
                    else existingPrePhases ++ [ "disableChecksPhase" ];
                  disableChecksPhase = ''
                    unset doCheck
                    unset doInstallCheck
                    # Override Python-specific check phases to be no-ops
                    pytestCheckPhase() { :; }
                    pythonImportsCheckPhase() { :; }
                  '';
                };
              buildPythonPackage = python-prev.buildPythonPackage // {
                __functor = self: args: python-prev.buildPythonPackage (python-final.disableCheckArgs args);
              };
              buildPythonApplication = python-prev.buildPythonApplication // {
                __functor = self: args: python-prev.buildPythonApplication (python-final.disableCheckArgs args);
              };
              psycopg = python-prev.psycopg.overridePythonAttrs (oldAttrs: {
                propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [ python-final.psycopg-pool ];
              });
              mutatormath = python-prev.mutatormath.overridePythonAttrs (old: {
                catchConflicts = false;
              });
              jeepney = python-prev.jeepney.overridePythonAttrs (old: {
                pythonImportsCheck = [ "jeepney" ];
              });
              fontparts = python-prev.fontparts.overridePythonAttrs (old: {
                catchConflicts = false;
                dontCheckRuntimeDeps = true;
              });
              ufoprocessor = python-prev.ufoprocessor.overridePythonAttrs (old: {
                catchConflicts = false;
                dontCheckRuntimeDeps = true;
              });
              afdko = python-prev.afdko.overridePythonAttrs (old: {
                dontCheckRuntimeDeps = true;
                catchConflicts = false;
              });

              img2pdf = python-prev.img2pdf.overridePythonAttrs (old: {
                src = final.fetchFromGitHub {
                  owner = "josch";
                  repo = "img2pdf";
                  rev = "0.6.1";
                  hash = "sha256-71u6ex+UAEFPDtR9QI8Ezah5zCorn4gMdAnzFz4blsI=";
                };
              });

              pyasn = python-prev.pyasn.overridePythonAttrs (old: {
                datasrc = old.datasrc.override {
                  hash = "sha256-7zpaxDe5qHUy/ekOJLxKawjaPQnByrOVj+m2bsUqfdg=";
                };
              });
              debugpy = python-prev.debugpy.overrideAttrs (oldAttrs: {
                src = oldAttrs.src.override {
                  hash = "sha256-eAiCtSJUqLASapxnYCyq1UCiGz6QmKQum7Vs3MoU1s8=";
                };
              });
              instructor = python-prev.instructor.overridePythonAttrs (old: {
                src = final.fetchFromGitHub {
                  owner = "jxnl";
                  repo = "instructor";
                  tag = "v1.11.3";
                  hash = "sha256-VWFrMgfe92bHUK1hueqJLHQ7G7ATCgK7wXr+eqrVWcw=";
                };
              });
              pypng = python-prev.pypng.overridePythonAttrs (old: {
                src = final.fetchFromGitLab {
                  owner = "drj11";
                  repo = "pypng";
                  tag = "pypng-0.20231004.0";
                  hash = "sha256-xNUI3yGfwmaccCxgljIZzgJ6YgNxcuOzCXDE7RFJP2I=";
                };
              });
              rank-bm25 = python-prev.rank-bm25.overridePythonAttrs (old: {
                src = final.fetchFromGitHub {
                  owner = "dorianbrown";
                  repo = "rank_bm25"; # Corrected from hyphen to underscore
                  tag = old.version; # Often tags are prefixed with 'v'
                  hash = "sha256-+BxQBflMm2AvCLAFFj52Jpkqn+KErwYXU1wztintgOg="; # Updated hash
                };
              });
            })
          ];
          haskellPackages = prev.haskellPackages.extend (
            hself: hsuper: {
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
                strace-macos = inputs.strace_macos.packages.aarch64-darwin.default;
                # nvim = my-nvim.defaultPackage.aarch64-darwin;
                nix = inputs.nix.packages.aarch64-darwin.default;
                hl = inputs.hl.packages."aarch64-darwin".default;
              })
            ];
          }
        ];
      };

      mymaster = nixpkgs-master;
      mything = pkgs;
      mything2 = nixpkgs.outPath;
    };
}

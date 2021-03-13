{

  description = "A highly awesome system configuration.";

  inputs = {
    unstable.url = "nixpkgs/master";
    master.url = "nixpkgs/master";
    nixpkgs.url = "nixpkgs/release-20.09";
    utilsGytis.url = github:gytis-ivaskevicius/flake-utils-plus;

    gytis-overlay = {
      url = "github:gytis-ivaskevicius/nixfiles/master";
      inputs.nixpkgs.follows = "unstable";
      inputs.master.follows = "unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-20.09";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "unstable";
    };

    mutt-colors-solarized = {
      url = "github:altercation/mutt-colors-solarized";
      flake = false;
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      flake = true;
      inputs.nixpkgs.follows = "unstable";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "unstable";
    };

    nyxt-overlay = {
      url = "github:atlas-engineer/nyxt";
      inputs.nixpkgs.follows = "unstable";
    };

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-doom-emacs = {
      url = "github:vlaci/nix-doom-emacs";
      # url = "github:vlaci/nix-doom-emacs/fix-gccemacs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "unstable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "unstable";
    };

    nix-dram = {
      url = "github:dramforever/nix-dram";
      inputs.nixpkgs.follows = "unstable";
    };

    nix-fast-syntax-highlighting = {
      url = "github:zdharma/fast-syntax-highlighting";
      flake = false;
      inputs.nixpkgs.follows = "unstable";
    };

    nix-zsh-shell-integration = {
      url = "github:chisui/zsh-nix-shell";
      flake = false;
      inputs.nixpkgs.follows = "unstable";
    };

    rust-filehost = {
      url = "github:DieracDelta/filehost_rust";
      inputs.nixpkgs.follows = "unstable";
    };
  };

  outputs = inputs@{ self, unstable, nixpkgs, rust-overlay
    , neovim-nightly-overlay, home-manager, nyxt-overlay, emacs-overlay
    , nix-doom-emacs, gytis-overlay, sops-nix, nix-dram, deploy-rs
    , rust-filehost, mailserver, mutt-colors-solarized, utilsGytis, ... }:
    let
      genNixosProfiles = (hostName: {
        ${hostName}.modules = [
          (import (./. + "/hosts/${hostName}.nixos.nix"))
          {
            home-manager.users.jrestivo = {
              imports = hmImports ++ [ (./. + "/hosts/${hostName}.hm.nix") ];
            };
          }
        ];
      });
      stable-pkgs = import ./overlays;
      pkgs = self.pkgs.nixpkgs;

      hmImports = [ inputs.nix-doom-emacs.hmModule ./home/home.nix ];

    in utilsGytis.lib.systemFlake {
      inherit self inputs;
      extraArgs = {inherit inputs builtins; };

      # TODO do I need this? YES YOU DO!
      pkgs.nixpkgs = {
        input = nixpkgs;
        overlays = [
          (final: prev: {
            inherit (self.pkgs.unstable-pkgs)
            manix maim nextcloud20 nix-du tailscale zerotierone;
            unstable = self.pkgs.unstable-pkgs;
          })
        ];
      };


      pkgs.unstable-pkgs.input = unstable;

      pkgsConfig = {
        allowUnfree = true;
        permittedInsecurePackages = [ "openssl-1.0.2u" ];
      };
      sharedModules = [
        (import "${gytis-overlay}/modules/clean-home.nix")
        mailserver.nixosModule
        (import ./custom_modules)
        sops-nix.nixosModules.sops
        nixpkgs.nixosModules.notDetected
        home-manager.nixosModules.home-manager
        {
          #gytix.cleanHome.enable = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];

      sharedOverlays = [
        (import ./overlays)
        neovim-nightly-overlay.overlay
        stable-pkgs
        emacs-overlay.overlay
        gytis-overlay.overlay
        nyxt-overlay.overlay

        (final: prev: {
          inherit (nix-dram.packages.${prev.system}) nix-search-pretty;
          inherit (deploy-rs.packages.${prev.system}) deploy-rs;
          mutt-colors-solarized = inputs.mutt-colors-solarized;
          nix-fast-syntax-highlighting = {
            name = "fast-sytax-highlighting";
            file = "fast-syntax-highlighting.plugin.zsh";
            src = "${inputs.nix-fast-syntax-highlighting.outPath}";
          };
          nix-zsh-shell-integration = {
            name = "zsh-shell-integration";
            file = "nix-shell.plugin.zsh";
            src = "${inputs.nix-zsh-shell-integration.outPath}";
          };
          rust-filehost = inputs.rust-filehost.packages.${prev.system}.filehost;
          nixUnstable = prev.nixUnstable.overrideAttrs (old: {
            patches = [
              (prev.fetchpatch {
                url = "https://raw.githubusercontent.com/dramforever/nix-dram/main/nix-patches/nix-search-meta.patch";
                sha256 = "sha256-MW9Qc4MZ1tYlSxunxKVCnDLJ7+LMY/JynMIrtp8lBlI=";
              })
            ];
          });
        })
      ];

      /*nixosProfiles.oracle_vps_1 = {*/
        /*modules = [*/
          /*(import ./hosts/oracle_vps_1.nixos.nix)*/
          /*{*/
            /*home-manager.users.jrestivo = {*/
              /*imports = hmImports ++ [ (./. + "/hosts/oracle_vps_1.hm.nix") ];*/
            /*};*/
          /*}*/
        /*];*/
      /*};*/


      devShell.${pkgs.system} = pkgs.mkShell {
        # imports all files ending in .asc/.gpg and sets $SOPS_PGP_FP.
        sopsPGPKeyDirs = [ "./secrets" ];
        nativeBuildInputs =
          [ (pkgs.callPackage sops-nix { }).sops-pgp-hook ];
        shellhook = "zsh";
      };

      # very simply get all the stuff in hosts/directory to provide as outputs
      nixosProfiles = 
      let
        dirs = pkgs.lib.filterAttrs (name: fileType: (fileType == "regular") && (pkgs.lib.hasSuffix ".nixos.nix" name)) (builtins.readDir ./hosts);
        fullyQualifiedDirs = (pkgs.lib.mapAttrsToList (name: _v: "${name}") dirs);
        hostName = map (path: pkgs.lib.removeSuffix ".nixos.nix" (baseNameOf "${path}" )) fullyQualifiedDirs;
        gennedProfiles = map genNixosProfiles hostName;
      in
      builtins.foldl' pkgs.lib.mergeAttrs {} (gennedProfiles);

      # deployment stuff
      deploy.nodes = {
        laptop = {
          hostname = "100.100.105.124";
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos
                self.nixosConfigurations.laptop;
            };
          };
        };

        desktop = {
          hostname = "100.107.190.11";
          fastConnection = true;
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos
                self.nixosConfigurations.desktop;
            };
          };
        };

        oracle_vps_1 = {
          hostname = "129.213.62.243";
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos
                self.nixosConfigurations.oracle_vps_1;
            };
          };
        };

        oracle_vps_2 = {
          hostname = "150.136.52.94";
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos
                self.nixosConfigurations.oracle_vps_2;
            };
          };
        };
      };

      # This is highly advised, and will prevent many possible mistakes
      checks = builtins.mapAttrs
        (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    };
}


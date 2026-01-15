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

    nix.url = "github:NixOS/nix/2.33.0";

    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unpatched.url = "github:NixOS/nixpkgs/master";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    comfyui-nix.url = "github:utensils/comfyui-nix";

    koito-src.url = "github:DieracDelta/Koito/jr/subpage";
    koito-src.flake = false;
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
      comfyui-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      tmp_pkgs = import nixpkgs-unpatched { localSystem = system; };
      nixpkgs = tmp_pkgs.applyPatches {
        name = "nixpkgs";
        src = nixpkgs-unpatched;
        patches = [
          ./PATCH_SUNSHINE
          ./PATCH_CONFIG_OPTIONS
          (tmp_pkgs.fetchpatch {
            url = "https://github.com/DieracDelta/nixpkgs/commit/a1d2240eebf50667a42b18c577c6a6f221e23e83.patch";
            hash = "sha256-mnBr3SXqfU4LekbX8v0Pqg2RsUHVijKbokPkUbArW2k=";
          })
        ];
      };
      inherit (nixpkgs-unpatched) lib;

      # Import modular overlays from ./overlays
      overlays = import ./overlays { inherit inputs; };

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
        comfyui-nix.nixosModules.default
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

      hydraJobs.x86_64-linux.desktop = self.nixosConfigurations.desktop.config.system.build.toplevel;
    };
}

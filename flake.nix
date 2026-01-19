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
        utils.buildNixosConfigurations fullyQualifiedDirs
        // {
          # ARM OCI instance - separate from x86 infrastructure (no znver3/CUDA/overlays)
          nixos-arm = nixpkgs-unpatched.lib.nixosSystem {
            system = "aarch64-linux";
            modules = [
              ./hosts/hw/oci_arm.nix
              ./custom_modules/sudo.nix
              home-manager.nixosModules.home-manager
              (
                { pkgs, lib, ... }:
                {
                  system.stateVersion = "25.11";
                  networking.hostName = "nixos-arm";

                  nixpkgs.config.allowUnfree = true;

                  documentation.enable = false;

                  nix.settings.experimental-features = [
                    "nix-command"
                    "flakes"
                  ];

                  environment.systemPackages = with pkgs; [
                    vim
                    git
                    htop
                  ];

                  users.users.jrestivo = {
                    isNormalUser = true;
                    extraGroups = [ "wheel" ];
                    openssh.authorizedKeys.keys = [
                      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5qlN93RBt99GVy6YDP3OMb7Yu4zwELvT5kvdTRnPzE9txmdxKiMM8eHGw4vBwcbmwY7y1wa+ijXwiT0PbwDUOQvVu8CzWHxBF0pz8LVy7XsBuQr9UtxXVV6D9KBKJJEQjpKgF0LTGOC3LSdHKqlH/4zUaUpE2ZPOaoS01S8YwNfRbr30XDeilMDD5rY0AVlydKFRZIbf/96fdo4HURKcjRMapTdYrdkj++FINCl4IDOId3UQR7Z8qDmx2IC6rOikMNMGwEFvgueCDHDuieqNfHn9LVv8gzCPZ0QtX5Ap+6FPNiUfBXuG1IK7RzeDicGUSXWfKFQImwo6pppArqvtqizEFY6WDBSso5XTveg3Z/gH5/jfMigElVAh8xob/NAW2lv6lHEjXtFVmk3N2Fz425SfXQp2qyaYOPGYohWt1ZwlMdkHYfYGtskaoUd9XCM3GC+aSSLkMPuaXtLS3aJ9R7jcz4sfXdU0s3Vd+jQl7c9n3lGYlZ59aKruUj50QtAs= jrestivo@jrestivo.local"
                    ];
                  };

                  security.sudo.wheelNeedsPassword = false;

                  # Tailscale VPN
                  services.tailscale.enable = true;

                  # Disable networkd wait-online (not needed, interfaces are unmanaged)
                  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

                  # Home-manager with minimal config
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.users.jrestivo = {
                    imports = [ ./home/minimal.nix ];
                  };
                }
              )
            ];
          };
        };

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

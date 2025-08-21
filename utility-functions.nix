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
      # inherit system overlays;
      inherit overlays;
      localSystem = "x86_64-linux";
      # {
      #   system = "x86_64-linux";
      #   gcc.arch = "znver3";
      #   gcc.tune = "znver3";
      #   gcc.abi = "64";
      # };

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
        cudaSupport = true;
        allowUnfree = true;
        # replaceStdenv = ({ pkgs }: pkgs.clangStdenv);

        # RUSTFLAGS = "-C target-cpu=znver3 ";
        # permittedInsecurePackages = [ "nix-2.15.3" ];

        allowUnsupportedSystem = true;
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

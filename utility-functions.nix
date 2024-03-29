{ lib
, self
, inputs
, system
, pkgs
, nixosModules
, ...
}:
let
  inherit (lib) removeSuffix;
  inherit (builtins) listToAttrs;
  genAttrs' = values: f: listToAttrs (map f values);

in
{
  pkgImport = pkgs: overlays: import pkgs {
    inherit system overlays;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [ "nix-2.15.3" ];

      allowUnsupportedSystem = true;
    };
  };

  buildNixosConfigurations = paths:
    genAttrs' paths (path:
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
                    let path = toString ./.; in
                    (lib.mapAttrsToList (name: _v: "${name}=${inputs.${name}}") inputs) ++ [ "repl=${path}/repl.nix" ];
                  registry =
                    (lib.mapAttrs'
                      (name: _v: lib.nameValuePair name ({ flake = inputs.${name}; }))
                      inputs) // { ${hostName}.flake = self; };
                };
              };

            in
            [
              /*this actually imports the specific host file*/
              (import path)
              global
            ] ++ (nixosModules hostName);

          specialArgs = {
            inherit system inputs builtins;
          };
        };
      });
}

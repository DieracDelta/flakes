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
      permittedInsecurePackages = [
        "openssl-1.0.2u"
      ];
    };
  };

  /*nixpkgs-head.pkgs = nixpkgs.pkgsMusl;*/

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
                nixpkgs = { inherit pkgs; config = pkgs.config; };

                nix.package = pkgs.nixUnstable;
                nix = {
                  extraOptions = ''
                    experimental-features = nix-command flakes
                  '';
                  gc = {
                    automatic = true;
                    dates = "weekly";
                    options = "--delete-older-than 7d --max-freed $((64 * 1024**3))";
                  };
                  optimise = {
                    automatic = true;
                    dates = [ "weekly" ];
                  };
                };

                nix.nixPath =
                  let path = toString ./.; in
                  (lib.mapAttrsToList (name: _v: "${name}=${inputs.${name}}") inputs) ++ [ "repl=${path}/repl.nix" ];
                nix.registry =
                  (lib.mapAttrs'
                    (name: _v: lib.nameValuePair name ({ flake = inputs.${name}; }))
                    inputs) // { ${hostName}.flake = self; };

                system.configurationRevision = lib.mkIf (self ? rev) self.rev;
              };

            in
            [
              /*this actually imports the specific host file*/
              (import path)
              global
            ] ++ (nixosModules hostName);

          extraArgs = {
            inherit system inputs builtins;
          };
        };
      });
}

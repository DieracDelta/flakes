let
  flake = builtins.getFlake (toString ./.);
in
  flake.inputs
#// flake.nixosConfigurations

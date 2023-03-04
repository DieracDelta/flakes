let
  flake = builtins.getFlake (toString ./.);
in
  {
    inherit flake;
    self = flake.inputs.self;
    pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; };
  }

let
  flake = builtins.getFlake (toString ./.);
  nixpkgs-head = import <nixpkgs-head> { };
in
{ inherit flake; }
// flake
// builtins
// nixpkgs-head
// nixpkgs-head.lib
  // flake.nixosConfigurations

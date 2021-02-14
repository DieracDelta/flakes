{ pkgs ? import <nixpkgs> { } }:
let extraPackages = import ./extraPackages.nix;
in
with pkgs;

mkShell {
  buildInputs = [
    (ghc.withHoogle extraPackages)
    haskellPackages.brittany
    haskellPackages.hlint
    haskellPackages.hoogle
    haskellPackages.ghcide
  ];
}

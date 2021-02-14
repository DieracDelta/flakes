{config, pkgs, lib, ...}:
with lib;
with builtins;
let
  /*make it stupid easy to add in a new module*/
  dirs = filterAttrs
    (name: fileType:
      (fileType == "regular") &&
      (hasSuffix ".nix" name)
      && (name != "default.nix"))
    (readDir ./. );
  fullyQualifiedFiles = (mapAttrsToList (name: _v: ./. + (concatStrings ["/" name]))) dirs;
in
{
  imports = fullyQualifiedFiles;
}


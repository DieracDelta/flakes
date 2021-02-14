{config, pkgs, lib, ...}:
with lib;
with builtins;
let
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


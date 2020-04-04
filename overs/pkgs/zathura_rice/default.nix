{ lib, stdenv, makeWrapper, zathura, fetchFromGitHub, bash, coreutils}:
  stdenv.mkDerivation rec {
    name = "zathura_pywal";
    version = 1.0;
    builder = "${bash}/bin/bash";
    args = [ ./builder.sh ];
    system = builtins.currentSystem;
    inherit coreutils;
    src = ./src;

  propagatedBuildInputs = [ zathura bash ];
  propagatedUserEnvPackages = [ bash zathura ] ;
  nativeBuildInputs = [ makeWrapper ];
}

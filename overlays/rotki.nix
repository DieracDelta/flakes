# Rotki portfolio tracker with local premium features
# Uses patched source from /home/jrestivo/dev/rotki
{ rotki-src }:
_final: prev: {
  rotki = rotki-src.packages.${prev.stdenv.hostPlatform.system}.default;
  rotki-backend = rotki-src.packages.${prev.stdenv.hostPlatform.system}.backend;
  rotki-frontend = rotki-src.packages.${prev.stdenv.hostPlatform.system}.frontend;
}

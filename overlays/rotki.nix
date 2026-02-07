# Rotki portfolio tracker with local premium features
# Uses patched source from /home/jrestivo/dev/rotki
{ rotki-src }:
final: prev: {
  rotki = rotki-src.packages.${prev.system}.default;
  rotki-backend = rotki-src.packages.${prev.system}.backend;
  rotki-frontend = rotki-src.packages.${prev.system}.frontend;
}

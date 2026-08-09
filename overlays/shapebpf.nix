{ shapebpf }:
final: _prev:
let
  upstreamPackage = shapebpf.packages.${final.stdenv.hostPlatform.system}.default;
in
{
  shapebpf = upstreamPackage;
}

# Haskell-related overlays
# - CPU-specific optimizations for znver3
# - Package-specific fixes
final: prev:
let
  inherit (final) lib;
  makeGhcOptions = opts: lib.concatStringsSep " " (map (opt: "--ghc-option=${opt}") opts);
in
{
  haskell = prev.haskell // {
    packageOverrides =
      hfinal: hprev:
      prev.lib.composeExtensions (prev.haskell.packageOverrides or (_: _: { })) (hfinal: hprev: {
        mkDerivation =
          args:
          hprev.mkDerivation (
            args
            // {
              configureFlags = (args.configureFlags or [ ]) ++ [
                (makeGhcOptions [
                  # "-fllvm"
                  "-optc=-march=znver3"
                  "-optlo=-mcpu=znver3"
                  "-O2"
                ])
              ];
              # GHC uses ld.gold which doesn't support pack-relative-relocs
              # Must run before compileBuildDriverPhase which compiles Setup.hs
              preCompileBuildDriver = (args.preCompileBuildDriver or "") + ''
                export NIX_CFLAGS_LINK="''${NIX_CFLAGS_LINK//-Wl,-z,pack-relative-relocs/}"
              '';
            }
          );
      }) hfinal hprev;
  };

  haskellPackages = prev.haskellPackages.extend (
    hself: hsuper: {
      xmobar = final.haskell.lib.compose.overrideCabal (drv: {
        enableSeparateBinOutput = false;
      }) hsuper.xmobar;
      cachix = final.haskell.lib.compose.overrideCabal (drv: {
        enableSeparateBinOutput = false;
      }) hsuper.cachix;
      yaml = final.haskell.lib.compose.overrideCabal (drv: {
        enableSeparateBinOutput = false;
      }) hsuper.yaml;
    }
  );

  xmobar = final.haskellPackages.xmobar;
}

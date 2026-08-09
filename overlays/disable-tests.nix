# Temporary local build-speed policy. Keep package-level test declarations in
# place so they remain visible and can be triaged when this overlay is removed.
_final: prev:
let
  disableChecks =
    attrs:
    attrs
    // {
      doCheck = false;
      doInstallCheck = false;
    };

  # Keep the wrapper when nixpkgs derives compiler/static variants with
  # `stdenv.override`. Mutating mkDerivationFromStdenv instead causes a fixed
  # point through recursive package scopes such as PHP's build environment.
  withoutChecks =
    stdenv:
    stdenv
    // {
      mkDerivation =
        fnOrAttrs:
        if builtins.isFunction fnOrAttrs then
          stdenv.mkDerivation (finalAttrs: disableChecks (fnOrAttrs finalAttrs))
        else
          stdenv.mkDerivation (disableChecks fnOrAttrs);

      override = args: withoutChecks (stdenv.override args);
    };
in
{
  stdenv = withoutChecks prev.stdenv;
  stdenvNoCC = withoutChecks prev.stdenvNoCC;
}

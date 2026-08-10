# Temporary local build-speed policy. Keep package-level test declarations in
# place so they remain visible and can be triaged when this overlay is removed.
final: prev:
let
  disableChecks =
    attrs:
    attrs
    // {
      doCheck = false;
      doInstallCheck = false;
    };

  disablePythonChecks =
    attrs:
    disableChecks attrs
    // {
      # These hooks run outside Python's standard install-check phase.
      dontUsePythonImportsCheck = true;
      dontCheckRuntimeDeps = true;
    };

  # Preserve buildPythonPackage.override while applying policy defaults to both
  # plain and final-attribute package definitions.
  withoutPythonChecks =
    builder:
    prev.lib.mirrorFunctionArgs builder (
      attrs:
      builder (
        if builtins.isFunction attrs then
          finalAttrs: disablePythonChecks (attrs finalAttrs)
        else
          disablePythonChecks attrs
      )
    )
    // {
      override = args: withoutPythonChecks (builder.override args);
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

  # vk-bootstrap uses its own option instead of CMake's conventional
  # BUILD_TESTING switch, so cmake's automatic no-check flag is insufficient.
  vk-bootstrap = prev.vk-bootstrap.overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DVK_BOOTSTRAP_TEST=OFF" ];
  });

  # This package derives its Meson test switch from finalAttrs.doCheck before
  # the outer stdenv argument wrapper removes check-only inputs.
  power-profiles-daemon = prev.power-profiles-daemon.overrideAttrs (old: {
    mesonFlags =
      builtins.filter (flag: flag != "-Dtests=true") (old.mesonFlags or [ ])
      ++ [ "-Dtests=false" ];
  });

  # Python package scopes capture their builders while nixpkgs constructs the
  # interpreter package sets. Rebind those builders to the policy stdenv so
  # explicit install checks cannot bypass the top-level wrapper.
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (_: pythonPrev: {
      buildPythonPackage = withoutPythonChecks (
        pythonPrev.buildPythonPackage.override {
          stdenv = final.stdenv;
        }
      );
      buildPythonApplication = withoutPythonChecks (
        pythonPrev.buildPythonApplication.override {
          stdenv = final.stdenv;
        }
      );
    })
  ];
}

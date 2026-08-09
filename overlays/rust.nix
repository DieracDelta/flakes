_final: prev:
let
  inherit (prev) lib;
  isZen3Target = (prev.stdenv.hostPlatform.gcc.arch or null) == "znver3";
in
lib.optionalAttrs isZen3Target {
  rustPlatform = prev.rustPlatform.overrideScope (
    _rustFinal: rustPrev: {
      buildRustPackage = lib.extendMkDerivation {
        constructDrv = rustPrev.buildRustPackage;
        extendDrvArgs = _finalAttrs: previousAttrs: {
          env = (previousAttrs.env or { }) // {
            NIX_RUSTFLAGS = lib.concatStringsSep " " (
              builtins.filter (value: value != "") [
                (toString (previousAttrs.env.NIX_RUSTFLAGS or ""))
                "-C target-cpu=znver3"
              ]
            );
          };
        };
      };
    }
  );
}

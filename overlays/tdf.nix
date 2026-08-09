# tdf overlay - build from DieracDelta/tdf fork
# Build as a fresh rust package so cargoLock can be a structured attrset.
final: prev:
let
  src = final.fetchFromGitHub {
    owner = "DieracDelta";
    repo = "tdf";
    rev = "50e6877686319ad163c9055b96ff6874bfda7d02";
    hash = "sha256-3VzAM+X2EutoLYuozNBW9Vv6xMJ27l9cTcioL7RjWqY=";
  };
in
{
  tdf = prev.rustPlatform.buildRustPackage {
    pname = "tdf";
    version = "unstable-2026-02-22";
    inherit src;

    cargoLock = {
      lockFile = "${src}/Cargo.lock";
      allowBuiltinFetchGit = true;
    };

    nativeBuildInputs = [ prev.pkg-config ];

    buildFeatures = [
      "epub"
      "cbz"
    ];

    buildInputs = [
      prev.rustPlatform.bindgenHook
      prev.cairo
    ];

    postInstall = ''
      rm "$out/bin/for_profiling"
    '';

    meta = prev.tdf.meta // {
      homepage = "https://github.com/DieracDelta/tdf";
    };
  };
}

final: prev:
let
  src = final.fetchFromGitHub {
    owner = "openai";
    repo = "codex";
    rev = "3fb81667d30d9d24297216ea61fbfcc4351b2aa9";
    hash = "sha256-1ZOaZlwAkH6DJpxlInfbXpaqmsbOIOGrFoj2dYehBMA=";
  };
  rustyV8Archive = final.fetchurl {
    url = "https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
    hash = "sha256-iu2YY323533Iv7i7R1nsW95HLQv3lD9Y4OYqNQlFxVk=";
  };
in
{
  codex = final.rustPlatform.buildRustPackage rec {
    pname = "codex";
    version = "0.141.0";

    inherit src;
    sourceRoot = "${src.name}/codex-rs";

    patches = [
      ../patches/codex-persistent-logs-warn-only.patch
    ];

    cargoLock = {
      lockFile = "${src}/codex-rs/Cargo.lock";
      allowBuiltinFetchGit = true;
    };

    cargoBuildFlags = [
      "-p"
      "codex-cli"
      "--bin"
      "codex"
    ];

    nativeBuildInputs = [
      final.makeWrapper
      final.pkg-config
    ];

    buildInputs = [
      final.openssl
      final.libcap
      final.libz
    ];

    RUSTY_V8_ARCHIVE = "${rustyV8Archive}";

    doCheck = false;

    postInstall = ''
      mv "$out/bin/codex" "$out/bin/codex-raw"
      makeWrapper "$out/bin/codex-raw" "$out/bin/codex" \
        --run 'export CODEX_EXECUTABLE_PATH="$HOME/.local/bin/codex"' \
        --set DISABLE_AUTOUPDATER 1 \
        --prefix PATH : "${final.lib.makeBinPath [ final.bubblewrap ]}"
    '';

    meta = prev.codex.meta // {
      description = "${prev.codex.meta.description or "OpenAI Codex CLI"} without persistent tracing sinks";
    };
  };
}

final: _prev:
let
  nodejs = final.nodejs_24;
  buildNpmPackage = final.buildNpmPackage.override { inherit nodejs; };

  commonRuntimePath = final.lib.makeBinPath [
    final.bash
    final.coreutils
    final.fd
    final.findutils
    final.git
    final.gnugrep
    final.gnused
    final.ripgrep
    final.tmux
  ];
in
{
  # Upstream publishes a versioned npm-style release archive rather than a
  # nixpkgs package. The tracked lock file pins that archive and every npm/R2
  # dependency; uv bootstraps Prime Agent's per-user IPython environment on the
  # first run.
  prime-agent = buildNpmPackage {
    pname = "prime-agent";
    version = "0.7.3";
    src = ./npm-apps/prime-agent;

    npmDepsHash = "sha256-LG4n+tokpAD4kvY5es1JzxAFrWHRs3D0Uj1DlAQy4ME=";
    dontNpmBuild = true;
    strictDeps = true;

    nativeBuildInputs = [
      final.autoPatchelfHook
      final.makeWrapper
    ];
    buildInputs = [
      final.stdenv.cc.cc.lib
      final.zeromq
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/prime-agent $out/bin
      cp -R node_modules $out/lib/prime-agent/node_modules
      # Keep the application itself outside a node_modules path so its
      # self-update detector reports an immutable/unknown installation instead
      # of suggesting a global npm mutation of the Nix store.
      mv $out/lib/prime-agent/node_modules/prime-agent $out/lib/prime-agent/package
      rm $out/lib/prime-agent/node_modules/.bin/prime-agent

      # koffi and zeromq publish native binaries for every supported OS/libc in
      # the same npm archive. Retain only the x86_64-linux/glibc variants so
      # autoPatchelf neither treats musl/OpenBSD binaries as broken NixOS ELFs
      # nor leaves unused cross-platform executables in the closure.
      find $out/lib/prime-agent/node_modules/koffi/build/koffi \
        -mindepth 1 -maxdepth 1 ! -name linux_x64 -exec rm -rf -- {} +
      find $out/lib/prime-agent/node_modules/zeromq/build \
        -mindepth 1 -maxdepth 1 -type d ! -name linux -exec rm -rf -- {} +
      find $out/lib/prime-agent/node_modules/zeromq/build/linux \
        -mindepth 1 -maxdepth 1 ! -name x64 -exec rm -rf -- {} +
      find $out/lib/prime-agent/node_modules/zeromq/build/linux/x64/node \
        -mindepth 1 -maxdepth 1 ! -name glibc-127-Release -exec rm -rf -- {} +

      makeWrapper ${nodejs}/bin/node $out/bin/prime-agent \
        --add-flags "$out/lib/prime-agent/package/dist/bundle/cli.js" \
        --prefix PATH : ${final.lib.makeBinPath [ final.python3 final.uv ]}:${commonRuntimePath}

      runHook postInstall
    '';

    passthru = {
      upstreamRev = "61131b2d195ba7a67a4ce8ac60bb10cecae07b67";
      # Prime's bundle contains extract-zip 2.0.1 (CVE-2026-56876), but the
      # affected code is its Windows-only fd/rg ZIP installer. This package is
      # Linux-only, where upstream selects tarballs, and the wrapper supplies
      # both tools in PATH so automatic provisioning is bypassed entirely.
      dormantUpstreamAdvisory = "CVE-2026-56876";
    };

    meta = with final.lib; {
      description = "Self-improving RLM coding and research agent";
      homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
      changelog = "https://github.com/PrimeIntellect-ai/prime-agent/releases/tag/v0.7.3";
      license = licenses.mit;
      mainProgram = "prime-agent";
      platforms = [ "x86_64-linux" ];
    };
  };

  # DeepSeek Harness is still a developer preview. Upstream publishes the CLI
  # and its plugin graph to npm; the lock file makes that graph reproducible.
  deepseek-harness = buildNpmPackage {
    pname = "deepseek-harness";
    version = "0.1.0-rc.7";
    src = ./npm-apps/deepseek-harness;

    npmDepsHash = "sha256-XrT66OagZfRi1YrFDzzYJYZVYJlsmr2GKUUnlUE9Ofg=";
    dontNpmBuild = true;
    strictDeps = true;

    # Keep upstream's native-addon RPATHs intact. In particular, rewriting the
    # bundled Sharp/libvips pair with autoPatchelf makes Sharp crash during
    # initialization; the unmodified x86_64-glibc artifacts pass runtime tests.
    nativeBuildInputs = [
      final.makeWrapper
      final.pkg-config
      final.python3
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/deepseek-harness $out/bin
      cp -R node_modules $out/lib/deepseek-harness/node_modules
      rm -rf $out/lib/deepseek-harness/node_modules/@koromix/koffi-linux-x64/musl_x64
      find $out/lib/deepseek-harness/node_modules/node-pty/prebuilds \
        -mindepth 1 -maxdepth 1 ! -name linux-x64 -exec rm -rf -- {} +

      makeWrapper ${nodejs}/bin/node $out/bin/dsh \
        --add-flags "--expose-internals" \
        --add-flags "$out/lib/deepseek-harness/node_modules/@deepseek-ai/dsh/lib/bin.js" \
        --prefix PATH : ${final.lib.makeBinPath [ final.pnpm ]}:${commonRuntimePath}

      runHook postInstall
    '';

    passthru.upstreamRev = "99f6f02fecdb7dff40c3fbc9470f5907c29f74ca";

    meta = with final.lib; {
      description = "Plugin-oriented DeepSeek agent harness (developer preview)";
      longDescription = ''
        The current upstream preview ships Web UI and headless profiles. It
        does not yet ship the future interactive TUI referenced by some of its
        archived design notes and CLI examples.
      '';
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = licenses.mit;
      mainProgram = "dsh";
      platforms = [ "x86_64-linux" ];
    };
  };
}

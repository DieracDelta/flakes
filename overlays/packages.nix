# Individual package overrides and custom packages
_: final: prev:
let
  # Import shared tmux-search-panes overlay
  tmuxOverlay = import ./tmux-search-panes.nix { } final prev;

  # Voyager - Spotify's ANN library (not in nixpkgs)
  voyager = final.python312Packages.buildPythonPackage rec {
    pname = "voyager";
    version = "2.1.0";
    format = "wheel";

    src = final.fetchPypi {
      inherit pname version format;
      dist = "cp312";
      python = "cp312";
      abi = "cp312";
      platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
      hash = "sha256-lBW5ySO6xJPVxo1VrlXEKJFTwj+fR4Qik03mGsuvTAE=";
    };

    # Binary wheel, no build deps needed
    propagatedBuildInputs = with final.python312Packages; [ numpy ];
    pythonImportsCheck = [ "voyager" ];

    meta = with final.lib; {
      description = "Spotify's library for approximate nearest-neighbor search";
      homepage = "https://github.com/spotify/voyager";
      license = licenses.asl20;
    };
  };

  # pyloudnorm - ITU-R BS.1770 loudness normalization
  # pyloudnorm = final.python312Packages.buildPythonPackage rec {
  #   pname = "pyloudnorm";
  #   version = "0.1.1";
  #   src = final.python312Packages.fetchPypi {
  #     inherit pname version;
  #     hash = "sha256-Y81OGX3qTneVFg6gjtAtMYCRvOiD5Dam28WWMya3Hh4=";
  #   };
  #   propagatedBuildInputs = with final.python312Packages; [ numpy scipy ];
  #   pythonImportsCheck = [ "pyloudnorm" ];
  #   meta = with final.lib; {
  #     description = "ITU-R BS.1770-4 loudness normalization in Python";
  #     homepage = "https://github.com/csteinmetz1/pyloudnorm";
  #     license = licenses.mit;
  #   };
  # };

  # AudioMuse-AI Python environment with all dependencies
  audiomuse-ai-python = final.python312.withPackages (
    ps: with ps; [
      # Web framework
      flask
      flask-cors
      flasgger

      # Task queue
      redis
      rq

      # Database
      psycopg2

      # Audio processing
      librosa
      soundfile
      resampy
      pydub
      mutagen

      # ML/Scientific
      numpy
      scipy
      numba
      pandas
      scikit-learn
      umap-learn
      transformers
      sentencepiece

      # ONNX
      onnx
      onnxruntime # CUDA enabled via global cudaSupport = true

      # GPU-accelerated ML (RAPIDS cuML)
      # Keep a single CUDA Python stack in the closure. Stock nixpkgs cupy currently
      # conflicts with the custom RAPIDS cuda-python/cuda-bindings packages below.
      final.python312Packages.rmm
      final.python312Packages.pylibraft
      final.python312Packages.cuvs
      final.python312Packages.cuml

      # Utilities
      pyyaml
      requests
      rapidfuzz
      ftfy
      packaging
      protobuf
      httpx

      # LLM integrations
      google-genai
      mistralai

      # MCP (Model Context Protocol)
      mcp

      # Loudness normalization
      # pyloudnorm

      # Voyager (from our custom package)
      voyager
    ]
  );
in
tmuxOverlay
// {
  # AudioMuse-AI - Music analysis and playlist generation service
  audiomuse-ai = final.stdenvNoCC.mkDerivation {
    pname = "audiomuse-ai";
    version = "unstable-2025-02-10";

    src = final.fetchFromGitHub {
      owner = "NeptuneHub";
      repo = "AudioMuse-AI";
      rev = "b67d2e6284b0be9ef9087cede3931192301c3374";
      hash = "sha256-bJllS4R9VvrDNrEc03eMTk5Pn8MrX/k5W+h6RTKS8lI=";
    };

    nativeBuildInputs = [ final.makeWrapper ];

    buildInputs = [
      audiomuse-ai-python
      final.ffmpeg
    ];

    postPatch = ''
      substituteInPlace config.py \
        --replace-fail 'TEMP_DIR = "/app/temp_audio"' 'TEMP_DIR = os.environ.get("TEMP_DIR", "/tmp/audiomuse-temp")' \
        --replace-fail 'EMBEDDING_MODEL_PATH = "/app/model/msd-musicnn-1.onnx"' \
                       'EMBEDDING_MODEL_PATH = os.environ.get("EMBEDDING_MODEL_PATH", "/app/model/msd-musicnn-1.onnx")' \
        --replace-fail 'PREDICTION_MODEL_PATH = "/app/model/msd-msd-musicnn-1.onnx"' \
                       'PREDICTION_MODEL_PATH = os.environ.get("PREDICTION_MODEL_PATH", "/app/model/msd-msd-musicnn-1.onnx")'

      # Fix CLAP Conv fallback: use EXHAUSTIVE algo search + relaxed memory arena
      substituteInPlace tasks/clap_analyzer.py \
        --replace-fail "'cudnn_conv_algo_search': 'DEFAULT'" \
                       "'cudnn_conv_algo_search': 'EXHAUSTIVE'" \
        --replace-fail "'arena_extend_strategy': 'kSameAsRequested'" \
                       "'arena_extend_strategy': 'kNextPowerOfTwo'"

      # Nixpkgs' mistralai 2.3.2 currently installs only metadata in this
      # environment. AudioMuse is configured to use Gemini, so don't make the
      # whole service depend on importing the optional Mistral client at startup.
      substituteInPlace ai.py \
        --replace-fail 'from mistralai import Mistral' \
                       $'try:\n    from mistralai import Mistral\nexcept ImportError:\n    Mistral = None' \
        --replace-fail '        client = Mistral(api_key=mistral_api_key)' \
                       $'        if Mistral is None:\n            return "Error: Mistral Python client is unavailable."\n\n        client = Mistral(api_key=mistral_api_key)'
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/audiomuse-ai
      cp -r . $out/lib/audiomuse-ai/

      mkdir -p $out/bin

      # Main Flask app
      makeWrapper ${audiomuse-ai-python}/bin/python $out/bin/audiomuse-ai \
        --add-flags "$out/lib/audiomuse-ai/app.py" \
        --prefix PATH : ${final.lib.makeBinPath [ final.ffmpeg ]} \
        --set PYTHONPATH "$out/lib/audiomuse-ai"

      # RQ Worker
      makeWrapper ${audiomuse-ai-python}/bin/python $out/bin/audiomuse-ai-worker \
        --add-flags "$out/lib/audiomuse-ai/rq_worker.py" \
        --prefix PATH : ${final.lib.makeBinPath [ final.ffmpeg ]} \
        --set PYTHONPATH "$out/lib/audiomuse-ai"

      # High-priority RQ Worker
      makeWrapper ${audiomuse-ai-python}/bin/python $out/bin/audiomuse-ai-worker-high \
        --add-flags "$out/lib/audiomuse-ai/rq_worker_high_priority.py" \
        --prefix PATH : ${final.lib.makeBinPath [ final.ffmpeg ]} \
        --set PYTHONPATH "$out/lib/audiomuse-ai"

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "AI-powered music analysis and playlist generation";
      homepage = "https://github.com/NeptuneHub/AudioMuse-AI";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  pam-insults = final.stdenv.mkDerivation {
    pname = "pam-insults";
    version = "unstable-2025-12-19";

    src = final.fetchFromGitHub {
      owner = "cgoesche";
      repo = "pam-insults";
      rev = "2d13ef89640eb57b5e6a64eea080e57d9d936738";
      hash = "sha256-VbEJCO7lvTDKvGpTXQrpgeWEpZE4CMdwaRSuv5shsbw=";
    };

    nativeBuildInputs = [
      final.asciidoctor
      final.gzip
    ];

    buildInputs = [
      final.pam
      final.gettext
    ];

    postPatch = ''
      substituteInPlace Makefile \
        --replace-fail "sudo " "" \
        --replace-fail "mandb" ""
    '';

    makeFlags = [
      "PAM_MODULES_DIR=$(out)/lib/security"
      "MAN_DATABASE=$(out)/share/man/man8"
    ];

    preInstall = ''
      mkdir -p $out/lib/security $out/share/man/man8
    '';

    meta = with final.lib; {
      description = "PAM module that will print an insult to stderr";
      homepage = "https://github.com/cgoesche/pam-insults";
      license = licenses.gpl3Plus;
      platforms = platforms.linux;
    };
  };

  # AudioMuse-AI ONNX models (~2GB total)
  audiomuse-ai-models = final.stdenvNoCC.mkDerivation {
    pname = "audiomuse-ai-models";
    version = "3.0.0";

    dontUnpack = true;

    # MusicNN models
    danceability = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/danceability-msd-musicnn-1.onnx";
      hash = "sha256-x7jlF0uC6gSVvKqcAmQJs/uOZSSfAsaj4HLC9VDP9No=";
    };
    mood_aggressive = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/mood_aggressive-msd-musicnn-1.onnx";
      hash = "sha256-HFV+PdXF8qUxlgeboYxu8cYjMpmZRS73imE6H0SXfoE=";
    };
    mood_happy = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/mood_happy-msd-musicnn-1.onnx";
      hash = "sha256-Q8S5L+3+YxUZWvpDNBw9jlyqE2vB7r9wr8EIEYryTeA=";
    };
    mood_party = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/mood_party-msd-musicnn-1.onnx";
      hash = "sha256-D5fwZtJEO7sqxs91QnBeVbLvVpZg4gxwEwNeyewvi1k=";
    };
    mood_relaxed = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/mood_relaxed-msd-musicnn-1.onnx";
      hash = "sha256-uQZYWQblqBPTwvrva1p3s2KWhCwPxcbrmnpr35oVh/Q=";
    };
    mood_sad = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/mood_sad-msd-musicnn-1.onnx";
      hash = "sha256-0Sjpf7coly19gnt4Gsso1xrD3LN7TUr9g6gS8WobJi0=";
    };
    msd_msd = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/msd-msd-musicnn-1.onnx";
      hash = "sha256-ug9Nv3teFAcEtfweq9ofdP45L6Zv2uhqSFN2waA4Beg=";
    };
    msd = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/msd-musicnn-1.onnx";
      hash = "sha256-6TR+BeNOID7gloTNLMewd+hAQnZvzZCKRqvHO8YqjZc=";
    };

    # CLAP models
    clap_audio = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/clap_audio_model.onnx";
      hash = "sha256-NBjHoJd4fIYzxlkQ/jVXcHHnMIS9LO6t7BnI+mC7KXY=";
    };
    clap_text = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/clap_text_model.onnx";
      hash = "sha256-IA1I85Bf8fJyr1AG3ZhR+UBxp93k6v2cB7wJxaxlpxQ=";
    };

    # HuggingFace models (BERT, RoBERTa, etc.)
    huggingface_models = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v3.0.0-model/huggingface_models.tar.gz";
      hash = "sha256-AqeNbkI0BMcnEWj3QPF+Q9vBCUf3Rt/EIFZwinRsyz0=";
    };

    nativeBuildInputs = [
      final.gnutar
      final.gzip
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/models

      # MusicNN models
      cp $danceability $out/models/danceability-msd-musicnn-1.onnx
      cp $mood_aggressive $out/models/mood_aggressive-msd-musicnn-1.onnx
      cp $mood_happy $out/models/mood_happy-msd-musicnn-1.onnx
      cp $mood_party $out/models/mood_party-msd-musicnn-1.onnx
      cp $mood_relaxed $out/models/mood_relaxed-msd-musicnn-1.onnx
      cp $mood_sad $out/models/mood_sad-msd-musicnn-1.onnx
      cp $msd_msd $out/models/msd-msd-musicnn-1.onnx
      cp $msd $out/models/msd-musicnn-1.onnx

      # CLAP models
      cp $clap_audio $out/models/clap_audio_model.onnx
      cp $clap_text $out/models/clap_text_model.onnx

      # HuggingFace models (extract tarball)
      mkdir -p $out/cache/huggingface
      tar -xzf $huggingface_models -C $out/cache/huggingface

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "ONNX models for AudioMuse-AI";
      homepage = "https://github.com/NeptuneHub/AudioMuse-AI";
      license = licenses.mit;
      platforms = platforms.all;
    };
  };

  # Navidrome plugins
  navidromePlugins = {
    # AudioMuse-AI plugin for Navidrome
    audiomuse-ai = final.buildGoModule {
      pname = "audiomuse-ai-nv-plugin";
      version = "unstable-2025-02-10";

      src = final.fetchFromGitHub {
        owner = "NeptuneHub";
        repo = "AudioMuse-AI-NV-plugin";
        rev = "c279bc118f1283f587247a36b9a9d654e6f52860";
        hash = "sha256-SWWafntBqdIZKvtXoa8efT2ChQeFU+8ms0YvmGu5t80=";
      };

      nativeBuildInputs = [ final.zip ];

      vendorHash = "sha256-pGusT8DChHLx1GZlBy4r/Ii6oILNwevc2EL4WkqhQIM=";

      env.CGO_ENABLED = "0";

      buildPhase = ''
        runHook preBuild
        GOOS=wasip1 GOARCH=wasm go build -buildmode=c-shared -o plugin.wasm .
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/navidrome-plugins
        zip -j $out/share/navidrome-plugins/audiomuse-ai.ndp plugin.wasm manifest.json
        runHook postInstall
      '';

      meta = with final.lib; {
        description = "AudioMuse-AI plugin for Navidrome - AI-powered similar tracks";
        homepage = "https://github.com/NeptuneHub/AudioMuse-AI-NV-plugin";
        license = licenses.mit;
      };
    };

    discord-rich-presence = final.buildGoModule {
      pname = "discord-rich-presence";
      version = "0.3.0";

      src = final.fetchFromGitHub {
        owner = "navidrome";
        repo = "discord-rich-presence-plugin";
        rev = "v0.3.0";
        hash = "sha256-gmRi4nb7KC3GC6ZcmaE/BPa9FgChCZ21K+VzLAeeZzI=";
      };

      nativeBuildInputs = [ final.zip ];

      vendorHash = "sha256-tJ6syjhiB8FFwYyFBX+iKsjFzqf6mUZQgTN7M2Saum8=";

      env.CGO_ENABLED = "0";

      buildPhase = ''
        runHook preBuild
        GOOS=wasip1 GOARCH=wasm go build -buildmode=c-shared -o plugin.wasm .
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/navidrome-plugins
        # Create .ndp package (zip file with manifest.json and plugin.wasm)
        zip -j $out/share/navidrome-plugins/discord-rich-presence.ndp plugin.wasm manifest.json
        runHook postInstall
      '';

      meta = with final.lib; {
        description = "Discord Rich Presence plugin for Navidrome";
        homepage = "https://github.com/navidrome/discord-rich-presence-plugin";
        license = licenses.gpl3Only;
      };
    };
  };

  # Navidrome 0.60.3 with plugin support
  # Use: pkgs.navidrome.override { plugins = with pkgs.navidromePlugins; [ discord-rich-presence ]; }
  navidrome = final.lib.makeOverridable (
    {
      plugins ? [ ],
    }:
    prev.navidrome.overrideAttrs (oldAttrs: rec {
      version = "0.60.3";
      src = final.fetchFromGitHub {
        owner = "navidrome";
        repo = "navidrome";
        rev = "v${version}";
        hash = "sha256-DwVmNJKjwEhTKIVPYFqaUR9SD4HpACkK4XJoFfQVRus=";
      };
      vendorHash = "sha256-StI4CfWN/OnbYFktRriTJWMHTuJkCinpYk9qgsxMGG8=";
      npmDeps = final.fetchNpmDeps {
        inherit src;
        sourceRoot = "${src.name}/ui";
        hash = "sha256-EA2WM7xaqP7rS0pjx+yXwpjdauaduvDefmFH73eByxI=";
      };

      postInstall = ''
        mkdir -p $out/share/plugins/
        ${final.lib.concatMapStringsSep "\n" (plugin: ''
          cp ${plugin}/share/navidrome-plugins/*.ndp $out/share/plugins/
        '') plugins}
      '';

      passthru = oldAttrs.passthru // {
        inherit plugins;
      };
    })
  ) { };

  # Agent Deck - TUI for managing AI coding agent sessions (Claude Code, Codex, etc.)
  agent-deck = final.buildGoModule {
    pname = "agent-deck";
    version = "1.7.79";

    src = final.fetchFromGitHub {
      owner = "asheshgoplani";
      repo = "agent-deck";
      rev = "v1.7.79";
      hash = "sha256-XJwm+ZtwaA8MbOWvY2523yUM3KvXDjhPBHxG23uhNZM=";
    };

    patches = [
      ../patches/agent-deck-preserve-collapsed-groups.patch
      ../patches/agent-deck-remove-csiureader.patch
    ];

    postPatch = ''
      substituteInPlace internal/session/conductor.go \
        --replace-fail "/bin/bash" "${final.bash}/bin/bash"
    '';

    vendorHash = "sha256-aH32Up3redCpeyjZkjcjiVN0tfYpF+GFB2WVAGm3J2I=";

    subPackages = [ "cmd/agent-deck" ];

    nativeBuildInputs = [ final.makeWrapper ];
    nativeCheckInputs = [ final.git ];

    postInstall = ''
      wrapProgram $out/bin/agent-deck \
        --prefix PATH : ${
          final.lib.makeBinPath [
            final.tmux
            final.git
            final.bash
          ]
        }
    '';

    meta = with final.lib; {
      description = "Terminal session manager for AI coding agents";
      homepage = "https://github.com/asheshgoplani/agent-deck";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  forgejo-mcp = final.buildGoModule rec {
    pname = "forgejo-mcp";
    version = "2.17.0";

    src = final.fetchFromGitHub {
      owner = "goern";
      repo = "forgejo-mcp";
      rev = "v${version}";
      hash = "sha256-DcpS2467MCFfIVsdYEfd5t6kPjMeLElMQbDyuXI04XE=";
    };

    patches = [ ../patches/forgejo-mcp-action-job-logs.patch ];

    vendorHash = "sha256-5CV4drUaYKtZ/RoydAatblhsqU8VWYzYByjhcb9KZVY=";

    meta = with final.lib; {
      description = "MCP server for interacting with Forgejo repositories";
      homepage = "https://github.com/goern/forgejo-mcp";
      license = licenses.mit;
      platforms = platforms.linux;
      mainProgram = "forgejo-mcp";
    };
  };

  forgejo = final.forgejo-lts;

  forgejo-lts = (
    final.callPackage (
      import "${prev.path}/pkgs/by-name/fo/forgejo/generic.nix" {
        version = "15.0.1";
        hash = "sha256-40hyQ6MPskyty/LsMVczuDpbu2q3Syoj3c00HUS+pVE=";
        npmDepsHash = "sha256-xWbnSX11RkLjtJ62qG6rD+xQAOnUuI99r9uEHakkZPY=";
        vendorHash = "sha256-JUBAcRYgflrvoAK0OvaU/Xr6/BakgaUtYwtvBF9vyk0=";
        lts = true;
      }
    ) { }
  ).overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../patches/forgejo-actions-api-jobs-logs.patch ];
  });

  nototools = prev.nototools.overridePythonAttrs (old: {
    dontCheckRuntimeDeps = true;
    catchConflicts = false;
  });

  # Fix dcgm-exporter to find ldconfig in PATH instead of hardcoded /sbin/ldconfig
  prometheus-dcgm-exporter = prev.prometheus-dcgm-exporter.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../patches/dcgm-exporter-fix-ldconfig.patch ];
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p $out/etc
      cp $src/etc/*.csv $out/etc/
    '';
  });

  # Fix azure-sdk-for-cpp packages with hardcoded sourceRoot
  # See: https://github.com/NixOS/nixpkgs/issues/... (same issue as influxdb2)
  azure-sdk-for-cpp = prev.azure-sdk-for-cpp.overrideScope (
    azureFinal: azurePrev: {
      core = azurePrev.core.overrideAttrs (
        finalAttrs: oldAttrs: {
          sourceRoot = "${finalAttrs.src.name}/sdk/core/azure-core";
        }
      );
      identity = azurePrev.identity.overrideAttrs (
        finalAttrs: oldAttrs: {
          sourceRoot = "${finalAttrs.src.name}/sdk/identity/azure-identity";
        }
      );
      storage-common = azurePrev.storage-common.overrideAttrs (
        finalAttrs: oldAttrs: {
          sourceRoot = "${finalAttrs.src.name}/sdk/storage/azure-storage-common";
        }
      );
      storage-blobs = azurePrev.storage-blobs.overrideAttrs (
        finalAttrs: oldAttrs: {
          sourceRoot = "${finalAttrs.src.name}/sdk/storage/azure-storage-blobs";
        }
      );
      storage-files-datalake = azurePrev.storage-files-datalake.overrideAttrs (
        finalAttrs: oldAttrs: {
          sourceRoot = "${finalAttrs.src.name}/sdk/storage/azure-storage-files-datalake";
        }
      );
    }
  );

  # Fix librttopo source URL - OSGeo gitea server returns 404
  # Use GitHub mirror instead
  librttopo = prev.librttopo.overrideAttrs (oldAttrs: {
    src = final.fetchFromGitHub {
      owner = "CGX-GROUP";
      repo = "librttopo";
      rev = "librttopo-1.1.0";
      hash = "sha256-VxyQr4nBy4PS2IjabBZHvzejFPDNBgSNn528ZCf99EA=";
    };
  });

  # osm2pgsql uses opencv which is built with CUDA - need CUDA toolkit for CMake to find nvcc
  osm2pgsql = prev.osm2pgsql.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
      final.cudaPackages.cuda_nvcc
    ];
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
      final.cudaPackages.cuda_cudart
    ];
  });

  # Koito - ListenBrainz-compatible scrobbler
  # Using local source with VITE_BASE_PATH env var for subpath deployment
  koito =
    let
      version = "1.0.0-subpath";
      src = final.fetchFromGitHub {
        owner = "DieracDelta";
        repo = "Koito";
        rev = "jr/subpage";
        hash = "sha256-uxmaLL3z/novKrRG4ZRB2/dfhOmuSfRqo8sdJJzc75w=";
      };

      # Frontend build using Yarn v1 hooks (recommended approach per nixpkgs docs)
      frontend = final.stdenv.mkDerivation {
        pname = "koito-frontend";
        inherit version;
        src = "${src}/client";

        yarnOfflineCache = final.fetchYarnDeps {
          yarnLock = "${src}/client/yarn.lock";
          hash = "sha256-mkA24dhMfm36q/8upplDqSQD8wklz/ndaYQzv9ycyeA=";
        };

        nativeBuildInputs = [
          final.yarnConfigHook # Installs deps from offline cache into node_modules
          final.yarnBuildHook # Runs yarn --offline build with proper PATH
          final.nodejs
        ];

        env.VITE_KOITO_VERSION = version;
        # Subpath deployment - set base path via env var (cleaner than patching)
        env.VITE_BASE_PATH = "/koito/";

        # Don't run yarnInstallHook - we just want the build output
        dontYarnInstall = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r build/client/* $out/
          runHook postInstall
        '';
      };
    in
    final.buildGoModule {
      pname = "koito";
      inherit version src;

      # Will compute on first build
      vendorHash = "sha256-e/gU29rPQUY+eugQxnjbb8UCJ3K4KCtRqJzBl5eFNxg=";

      env.CGO_ENABLED = "1";

      nativeBuildInputs = [ final.pkg-config ];
      buildInputs = [ final.vips ];

      ldflags = [
        "-s"
        "-w"
        "-X main.Version=${version}"
      ];

      subPackages = [ "cmd/api" ];

      # Bundle frontend and assets
      postInstall = ''
        mkdir -p $out/share/koito/client/build/client
        mkdir -p $out/share/koito/client/public

        # Copy frontend build to client/build/client/ (where Koito expects it)
        cp -r ${frontend}/* $out/share/koito/client/build/client/

        # Copy public assets to client/public/
        cp -r $src/client/public/* $out/share/koito/client/public/

        # Copy database migrations
        cp -r $src/db $out/share/koito/

        # Copy assets (default images, fonts for rewind generation)
        cp -r $src/assets $out/share/koito/

        # Rename binary
        mv $out/bin/api $out/bin/koito
      '';

      meta = with final.lib; {
        description = "ListenBrainz-compatible scrobbler";
        homepage = "https://github.com/gabehf/koito";
        license = licenses.agpl3Plus;
        platforms = platforms.linux;
      };
    };

  # Multi-scrobbler - scrobble from multiple sources to multiple clients
  # Using local source for subpath deployment fixes
  # claude-tmux - TUI for managing Claude Code tmux sessions
  claude-tmux = final.rustPlatform.buildRustPackage {
    pname = "claude-tmux";
    version = "0.3.0";

    src = final.fetchFromGitHub {
      owner = "nielsgroen";
      repo = "claude-tmux";
      rev = "212a5b55cc88e35feb7fd14b4508959a60a625ca";
      hash = "sha256-fNBT3DItgTrO0vKhjAAQ6L6/K9SBpvXEnyNUOq1AP4M=";
    };

    cargoHash = "sha256-AKBNCHx6Ap6HKddwzxs/qfJhJDE7LdZ/tRKO94ugRkA=";

    nativeBuildInputs = [ final.pkg-config ];
    buildInputs = [ final.openssl ];

    meta = with final.lib; {
      description = "TUI for managing Claude Code tmux sessions";
      homepage = "https://github.com/nielsgroen/claude-tmux";
      license = licenses.agpl3Only;
      platforms = platforms.linux;
    };
  };

  claude-chill = final.rustPlatform.buildRustPackage {
    pname = "claude-chill";
    version = "0.1.0";

    src = final.fetchFromGitHub {
      owner = "davidbeesley";
      repo = "claude-chill";
      rev = "e9f2b0368486ca1a4909b80acc83c13221fcd893";
      hash = "sha256-EFGWHQX6Etji74s4yNBT5luunnu/260o41YGiWcKkiU=";
    };

    cargoHash = "sha256-nxzO5sjzzGNDwrI18T8jSYhk8cyISIYIBuYUcH2rPX8=";

    meta = with final.lib; {
      description = "PTY proxy to reduce terminal flicker for Claude CLI";
      homepage = "https://github.com/davidbeesley/claude-chill";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  multi-scrobbler = final.buildNpmPackage {
    pname = "multi-scrobbler";
    version = "0.10.8-subpath";

    src = final.fetchFromGitHub {
      owner = "DieracDelta";
      repo = "multi-scrobbler";
      rev = "jr/multi-scrobbler";
      hash = "sha256-GOBOFOqKQq9PMtvZI+0GSHmRn1eDIsgguhWQE6jJTkc=";
    };

    npmDepsHash = "sha256-bmxtrQ7qEi/3dz2KTkqG4r90ohxYDKTRYsxmCux6UEg=";

    nodejs = final.nodejs_22;

    # Subpath deployment - set base URL for frontend build
    # Multi-scrobbler's vite.config.ts reads BASE_URL and sets Vite's `base` option
    env.BASE_URL = "https://localhost/scrobbler";
    # Use hash router for subpath deployment (avoids conflicts with reverse proxy path stripping)
    env.USE_HASH_ROUTER = "true";

    # Fix vite.config.ts to use pathname only (not full URL) for Vite's base option
    # This ensures assets work correctly when accessed via any hostname
    postPatch = ''
            substituteInPlace vite.config.ts \
              --replace-fail 'baseUrlStr = baseUrl.toString();' 'baseUrlStr = baseUrl.pathname + "/";'

            # Skip runtime schema generation - schemas are pre-generated and ts-json-schema-generator
            # fails in Nix runtime because it requires TypeScript type checking
            substituteInPlace src/backend/index.ts \
              --replace-fail "initLogger.info('Generating schema definitions...');" "// Schema generation skipped - using pre-generated schemas" \
              --replace-fail "createVegaGenerator()" "// createVegaGenerator() - skipped" \
              --replace-fail "initLogger.info('Schema definitions generated');" "// Schema definitions loaded from pre-generated files"

            # Fix static file serving - serve dist directly instead of relying on ViteExpress
            substituteInPlace src/backend/server/index.ts \
              --replace-fail "//app.use(express.static(buildDir));" "app.use(express.static(path.resolve(projectDir, 'dist')));"

            # Don't let ViteExpress override the base path at runtime - we handle it at build time
            # This ensures Caddy can strip /scrobbler/ prefix and Express serves at /
            substituteInPlace src/backend/server/index.ts \
              --replace-fail "base: localDefined && local.pathname !== '/' ? local.toString() : '/'" "base: '/'"

            # Replace SchemaUtils.ts - skip runtime schema generation entirely
            # Return permissive schemas that accept any valid JSON
            cat > src/backend/utils/SchemaUtils.ts << 'SCHEMAEOF'
      export const createVegaGenerator = () => null;

      // Return a permissive schema that accepts any object
      // The pre-generated schemas exist but extracting sub-types is complex
      // Config validation will be lenient but the app will run
      export const getTypeSchemaFromConfigGenerator = (type: string): any => {
        return { type: "object", additionalProperties: true };
      }
      SCHEMAEOF
    '';

    # Skip docsite build - it has a separate package.json and isn't needed at runtime
    # Also skip schema generation which requires the docsite
    buildPhase = ''
      runHook preBuild
      npm run build:backend
      npm run build:frontend

      # Fix manifest.json - Vite doesn't update relative paths in public files
      # These need to be absolute so they work when served via Caddy's path stripping
      ${final.jq}/bin/jq '.icons |= map(.src = "/scrobbler/" + .src) | .start_url = "/scrobbler/"' \
        dist/manifest.json > dist/manifest.json.tmp && mv dist/manifest.json.tmp dist/manifest.json

      runHook postBuild
    '';

    # Don't run default npm install phase - we handle it
    dontNpmInstall = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/multi-scrobbler
      cp -r dist $out/lib/multi-scrobbler/
      cp -r node_modules $out/lib/multi-scrobbler/
      cp package.json $out/lib/multi-scrobbler/

      # Copy source for tsx runtime (some files are still loaded from src)
      cp -r src $out/lib/multi-scrobbler/

      mkdir -p $out/bin
      cat > $out/bin/multi-scrobbler <<EOF
      #!${final.runtimeShell}
      cd $out/lib/multi-scrobbler
      exec ${final.nodejs_22}/bin/node --import tsx src/backend/index.ts "\$@"
      EOF
      chmod +x $out/bin/multi-scrobbler

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Scrobble plays from multiple sources to multiple clients";
      homepage = "https://github.com/FoxxMD/multi-scrobbler";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  linear-cli =
    let
      version = "1.10.0";
      releaseBySystem = {
        x86_64-linux = {
          target = "x86_64-unknown-linux-gnu";
          hash = "sha256-UZUYUkcHmh/cCM2xAxAeJrG1sdBj1fTB2n7HknjTdVg=";
        };
        aarch64-linux = {
          target = "aarch64-unknown-linux-gnu";
          hash = "sha256-QhBfvG5T67x3zpVVkcTPx+WL2+5niMYXbmoq/Hx2fko=";
        };
        x86_64-darwin = {
          target = "x86_64-apple-darwin";
          hash = "sha256-5HccJyxSjrCJbvEABBImfbgFDbLRiyP4HOFMylbR+DA=";
        };
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          hash = "sha256-gpxeAIKLgmc+UXTtFFME6pra5MElj7frWbGNSJQk7Ak=";
        };
      };
      release =
        releaseBySystem.${final.stdenv.hostPlatform.system}
          or (throw "linear-cli: unsupported system ${final.stdenv.hostPlatform.system}");
      linear-bin = final.stdenvNoCC.mkDerivation {
        pname = "linear-cli-bin";
        inherit version;

        src = final.fetchurl {
          url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-${release.target}.tar.xz";
          hash = release.hash;
        };

        sourceRoot = "linear-${release.target}";

        installPhase = ''
          runHook preInstall
          install -Dm755 linear $out/bin/linear
          runHook postInstall
        '';
      };
    in
    if final.stdenv.hostPlatform.isLinux then
      let
        linear-fhs = final.buildFHSEnv {
          name = "linear-cli-fhs";
          targetPkgs = _pkgs: [ ];
          runScript = "${linear-bin}/bin/linear";
        };
      in
      final.writeShellApplication {
        name = "linear";
        text = ''
          exec ${linear-fhs}/bin/linear-cli-fhs "$@"
        '';
      }
    else
      final.stdenvNoCC.mkDerivation {
        pname = "linear-cli";
        inherit version;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          ln -s ${linear-bin}/bin/linear $out/bin/linear
          runHook postInstall
        '';

        meta = with final.lib; {
          description = "CLI for Linear issue tracker";
          homepage = "https://github.com/schpet/linear-cli";
          license = licenses.mit;
          mainProgram = "linear";
          platforms = builtins.attrNames releaseBySystem;
        };
      };
}

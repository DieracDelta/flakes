# Individual package overrides and custom packages
_:
final: prev: {
  tmuxPlugins = prev.tmuxPlugins // {
    search-panes = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "search-panes";
      version = "0-unstable-2025-04-22";
      src = final.fetchFromGitHub {
        owner = "multi-io";
        repo = "tmux-search-panes";
        rev = "3996b5c56c6be69d3a85ef26065b1877d9ac71c6";
        hash = "sha256-Z9Gu4v2LAyG6UxXVLTvQUz1wU4PaJlBQXjLiSzfSP7s=";
      };
      rtpFilePath = "tmux-search-panes.tmux";
      nativeBuildInputs = [ final.makeWrapper ];
      postInstall = ''
        for f in search-panes.sh _fzf-and-switch.sh _render-preview.sh; do
          chmod +x $target/bin/$f
          wrapProgram $target/bin/$f \
            --prefix PATH : ${
              final.lib.makeBinPath [
                final.coreutils
                final.fzf
                final.gnugrep
                final.gnused
                final.tmux
              ]
            }
        done
      '';
      meta = {
        homepage = "https://github.com/multi-io/tmux-search-panes";
        description = "Tmux plugin for fulltext search across all panes";
        license = final.lib.licenses.mit;
        platforms = final.lib.platforms.unix;
        maintainers = [ final.lib.maintainers.DieracDelta ];
      };
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

  nototools = prev.nototools.overridePythonAttrs (old: {
    dontCheckRuntimeDeps = true;
    catchConflicts = false;
  });

  # Fix dcgm compilation with GCC 15 (missing include and typo)
  dcgm = prev.dcgm.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../patches/dcgm-fix-gcc15.patch ];
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
}

# Actual Budget overlay - builds from fork with base path support
final: prev:
let
  # Fetch from DieracDelta fork with subpath support
  actualSrc = prev.fetchFromGitHub {
    name = "actual-src";
    owner = "DieracDelta";
    repo = "actual";
    rev = "cc52121957ce4916855588c7e495bb4249a2bdbe";
    hash = "sha256-+QH6fW0rqucSApNiNUK2PDMgz1P/e7hB73oD87XDu8c=";
  };

  # Fetch translations separately (same as upstream)
  translations = prev.fetchFromGitHub {
    name = "actualbudget-translations-source";
    owner = "actualbudget";
    repo = "translations";
    rev = "570f8db9dd436810e014d587b4d27105bce7dfda";
    hash = "sha256-fVyO4rMgbdI1Hm3J4ka9/72sNcwlfLS6Ef06YUvx4Gs=";
  };

  nodejs = prev.nodejs_22;
  yarn-berry = prev.yarn-berry_4.override { inherit nodejs; };

  # Shared offline cache for both server and API builds
  offlineCache = yarn-berry.fetchYarnBerryDeps {
    src = actualSrc;
    missingHashes = ./actual-missing-hashes.json;
    hash = "sha256-ce4/hhdE0OjBFbALYqpxUFD9XDz0tC3G9xdCjPDa7mM=";
  };
in
{
  actual-server = prev.actual-server.overrideAttrs (oldAttrs: {
    version = "local-basepath";

    src = actualSrc;
    srcs = [
      actualSrc
      translations
    ];
    sourceRoot = "actual-src/";

    # Add ACTUAL_BASE_PATH to env for vite build
    env = (oldAttrs.env or { }) // {
      ACTUAL_BASE_PATH = "/actual";
    };

    postPatch = ''
      ln -sv ../../../${translations.name} ./packages/desktop-client/locale

      patchShebangs --build ./bin ./packages/*/bin

      # Patch all references to `git` to a no-op `true`. This neuter automatic
      # translation update.
      substituteInPlace bin/package-browser \
        --replace-fail "git" "true"

      # Allow `remove-untranslated-languages` to do its job.
      chmod -R u+w ./packages/desktop-client/locale

      # Disable the postinstall script for `protoc-gen-js` because it tries to
      # use network in buildPhase. It's just used as a dev tool and the generated
      # protobuf code is committed in the repository.
      cat <<< $(${prev.lib.getExe prev.jq} '.dependenciesMeta."protoc-gen-js".built = false' ./package.json) > ./package.json

      # Disable building @swc/core from source - use the pre-built binaries instead
      cat <<< $(${prev.lib.getExe prev.jq} '.dependenciesMeta."@swc/core".built = false' ./package.json) > ./package.json

      # Disable the install script for sharp to prevent it from trying to download binaries
      cat <<< $(${prev.lib.getExe prev.jq} '.dependenciesMeta."sharp".built = false' ./package.json) > ./package.json
    '';

    buildPhase = ''
      runHook preBuild

      export HOME=$(mktemp -d)
      export ACTUAL_BASE_PATH="/actual"

      yarn build:server
      yarn workspace @actual-app/sync-server build

      runHook postBuild
    '';

    # Fetch yarn dependencies from local source
    missingHashes = ./actual-missing-hashes.json;
    inherit offlineCache;
  });

  # Build @actual-app/api from the same fork for headless bank sync
  actual-api = prev.actual-server.overrideAttrs (oldAttrs: {
    pname = "actual-api";
    version = "local-basepath";

    src = actualSrc;
    srcs = [ actualSrc ];
    sourceRoot = "actual-src/";

    # Need build tools for better-sqlite3 native compilation
    # stdenv already provides a working compiler, just need python for node-gyp
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
      prev.python3
    ];

    postPatch = ''
      patchShebangs --build ./bin ./packages/*/bin

      # Disable the postinstall script for `protoc-gen-js`
      cat <<< $(${prev.lib.getExe prev.jq} '.dependenciesMeta."protoc-gen-js".built = false' ./package.json) > ./package.json

      # Disable building @swc/core from source
      cat <<< $(${prev.lib.getExe prev.jq} '.dependenciesMeta."@swc/core".built = false' ./package.json) > ./package.json

      # Disable the install script for sharp
      cat <<< $(${prev.lib.getExe prev.jq} '.dependenciesMeta."sharp".built = false' ./package.json) > ./package.json
    '';

    buildPhase = ''
      runHook preBuild

      export HOME=$(mktemp -d)

      # Build the API package (this also builds loot-core as a dependency)
      # better-sqlite3 is built during yarn install phase
      yarn workspace @actual-app/api build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # Create node_modules structure for the API
      mkdir -p $out/lib/node_modules/@actual-app/api

      # Copy the built API
      cp -r packages/api/dist $out/lib/node_modules/@actual-app/api/
      cp packages/api/package.json $out/lib/node_modules/@actual-app/api/

      # Copy runtime dependencies from the workspace
      # better-sqlite3 is built during yarn install against nodejs_22
      mkdir -p $out/lib/node_modules
      cp -r node_modules/better-sqlite3 $out/lib/node_modules/ || true
      cp -r node_modules/bindings $out/lib/node_modules/ || true
      cp -r node_modules/file-uri-to-path $out/lib/node_modules/ || true
      cp -r node_modules/google-protobuf $out/lib/node_modules/ || true
      cp -r node_modules/compare-versions $out/lib/node_modules/ || true
      cp -r node_modules/uuid $out/lib/node_modules/ || true

      runHook postInstall
    '';

    inherit offlineCache;
    missingHashes = ./actual-missing-hashes.json;
  });
}

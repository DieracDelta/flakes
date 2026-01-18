# Actual Budget overlay - builds from local source with base path support
{ actual-src }:
final: prev:
let
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

  # Copy local source to store with a known name
  actualSrc = prev.runCommand "actual-src" { } ''
    cp -r ${actual-src} $out
    chmod -R u+w $out
  '';
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
    # Using upstream missing-hashes.json as base - may need updates if deps changed significantly
    missingHashes = ./actual-missing-hashes.json;
    offlineCache = yarn-berry.fetchYarnBerryDeps {
      src = actualSrc;
      missingHashes = ./actual-missing-hashes.json;
      hash = "sha256-ce4/hhdE0OjBFbALYqpxUFD9XDz0tC3G9xdCjPDa7mM=";
    };
  });
}

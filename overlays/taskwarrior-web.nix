# Taskwarrior Web UI overlay - builds from GitHub
final: prev:
let
  src = prev.fetchFromGitHub {
    owner = "tmahmood";
    repo = "taskwarrior-web";
    rev = "2fba9a707f925dbfc99f24432fa400f596ee4e80";
    hash = "sha256-ub6zjBW+qMZVMQOudBaPpBT8BKvTAGaWLHuj8ih5+iI=";
  };
  version = "2.0.1";

  # Build frontend separately with buildNpmPackage
  frontend = prev.buildNpmPackage {
    pname = "taskwarrior-web-frontend";
    inherit version;
    src = "${src}/frontend";

    npmDepsHash = "sha256-KL+ZJIK91NCNug9MiIrTV5MtTme5kDIbpif8izxxdQQ=";

    # Upstream doesn't have package-lock.json, copy our generated one
    postPatch = ''
      cp ${./taskwarrior-web-package-lock.json} package-lock.json
    '';

    # Build in TMPDIR since source is read-only
    buildPhase = ''
      runHook preBuild
      export DIST=$TMPDIR/dist
      mkdir -p $DIST

      # Build tailwindcss
      npx @tailwindcss/cli -i css/style.css -o $DIST/style.css

      # Copy entire project to writable location for rollup (needs to write to dist/)
      cp -r ${src} $TMPDIR/src
      chmod -R u+w $TMPDIR/src

      # Copy node_modules from buildNpmPackage (current dir) to the project copy
      cp -r node_modules $TMPDIR/src/frontend/

      cd $TMPDIR/src

      # Current upstream templates inline the stylesheet and JavaScript bundle,
      # so no URL rewriting is required for subpath hosting.

      npx --prefix frontend rollup -c frontend/rollup.config.js
      cp dist/bundle.js $DIST/
      cp -r frontend/templates $DIST/

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r $TMPDIR/dist $out
      runHook postInstall
    '';
  };
in
{
  taskwarrior-web = prev.rustPlatform.buildRustPackage {
    pname = "taskwarrior-web";
    inherit version src;

    cargoLock = {
      lockFile = "${src}/Cargo.lock";
    };

    # sqlite is needed by taskchampion
    buildInputs = [ prev.sqlite ];
    nativeBuildInputs = [ prev.pkg-config ];

    # Copy pre-built frontend before build
    preBuild = ''
      mkdir -p dist
      cp -r ${frontend}/* dist/
    '';

    # Patch build.rs to skip npm commands since dist/ is pre-populated
    postPatch = ''
      substituteInPlace build.rs \
        --replace-fail 'if !Command::new("npm")' 'if false && !Command::new("npm")' \
        --replace-fail 'if !Command::new("frontend/node_modules/.bin/tailwindcss")' 'if false && !Command::new("frontend/node_modules/.bin/tailwindcss")' \
        --replace-fail 'if !Command::new("frontend/node_modules/.bin/rollup")' 'if false && !Command::new("frontend/node_modules/.bin/rollup")' \
        --replace-fail 'if !Command::new("cp")' 'if false && !Command::new("cp")'
    '';

    # Install dist/ directory for runtime templates
    postInstall = ''
      cp -r dist $out/
    '';

    env = {
      RUSTC_BOOTSTRAP = 1;
    };

    meta = with prev.lib; {
      description = "Minimalistic Web UI for Taskwarrior";
      homepage = "https://github.com/tmahmood/taskwarrior-web";
      license = licenses.mit;
      mainProgram = "taskwarrior-web";
    };
  };
}

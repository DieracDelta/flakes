{ config, pkgs, lib, ... }:

let
  cfg = config.services.digitransit;

  # Python with setuptools for node-gyp (distutils removed in Python 3.12+)
  pythonWithSetuptools = pkgs.python3.withPackages (ps: [ ps.setuptools ]);

  # Custom config file for NY/CT region
  customConfig = ./digitransit-config.newyork.js;

  # Pelias-Nominatim proxy script for geocoding
  geocodingProxyScript = ./pelias-nominatim-proxy.js;

  # Fetch digitransit-ui source
  digitransit-ui-src = pkgs.fetchFromGitHub {
    owner = "HSLdevcom";
    repo = "digitransit-ui";
    rev = "c643e807791db112dd01f62a8c55d5fe6bc7646a"; # v3 branch
    hash = "sha256-bfC+g1MJoV8G+DgPT8xZBMlTfO6gZxAD2tU1yyecRC0=";
  };

  # Build digitransit-ui using yarn-berry
  digitransit-ui = pkgs.stdenv.mkDerivation {
    pname = "digitransit-ui";
    version = "3.0.0";
    src = digitransit-ui-src;

    nativeBuildInputs = [
      pkgs.nodejs_20
      pkgs.yarn-berry_3
      pkgs.yarn-berry_3-fetcher.yarnBerryConfigHook
      pythonWithSetuptools
      pkgs.pkg-config
      pkgs.faketty
      # For native node modules
      pkgs.gnumake
      pkgs.gcc
    ];

    # Missing hashes for packages without checksums in yarn.lock
    missingHashes = ./digitransit-missing-hashes.json;

    # Offline cache for yarn dependencies
    offlineCache = pkgs.yarn-berry_3-fetcher.fetchYarnBerryDeps {
      src = digitransit-ui-src;
      missingHashes = ./digitransit-missing-hashes.json;
      hash = "sha256-Gwyq9cj3jAFy2Y9gyvp4sw8EXv9Mh0RwtXGBlzCOO6c=";
    };

    # Copy custom config into source tree before build
    postPatch = ''
      cp ${customConfig} app/configurations/config.newyork.js
    '';

    env = {
      CYPRESS_INSTALL_BINARY = "0";
      PUPPETEER_SKIP_DOWNLOAD = "1";
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      NODE_OPTIONS = "--max_old_space_size=4096";
      NODE_ENV = "production";
      CONFIG = "newyork";
      # Point node-gyp to python with setuptools (for distutils)
      PYTHON = "${pythonWithSetuptools}/bin/python3";
    };

    buildPhase = ''
      runHook preBuild

      export HOME=$(mktemp -d)

      # Build workspaces (yarn scripts don't need --immutable/--offline)
      faketty yarn run build-workspaces || true

      # Build main app
      faketty yarn run build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/digitransit-ui

      # Copy everything like Docker does, excluding unnecessary dirs
      # The Dockerfile does: COPY --from=builder /opt/digitransit-ui/ .
      # After removing: static docs .cache
      cp -r . $out/lib/digitransit-ui/

      # Remove unnecessary directories to save space
      rm -rf $out/lib/digitransit-ui/docs
      rm -rf $out/lib/digitransit-ui/.cache
      rm -rf $out/lib/digitransit-ui/test
      rm -rf $out/lib/digitransit-ui/.git
      rm -rf $out/lib/digitransit-ui/.yarn/cache

      # Create wrapper script
      mkdir -p $out/bin
      cat > $out/bin/digitransit-ui <<'EOF'
      #!/usr/bin/env bash
      export NODE_ENV=''${NODE_ENV:-production}
      export CONFIG=''${CONFIG:-newyork}
      export OTP_URL=''${OTP_URL:-http://localhost:8084/otp/}
      export PORT=''${PORT:-8080}
      cd ${placeholder "out"}/lib/digitransit-ui
      exec ${pkgs.nodejs_20}/bin/node server/server.js "$@"
      EOF
      chmod +x $out/bin/digitransit-ui

      runHook postInstall
    '';

    dontStrip = true;
  };

in
{
  options.services.digitransit = {
    enable = lib.mkEnableOption "Digitransit trip planning UI";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8085;
      description = "Port for Digitransit UI";
    };

    otpUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:8084/otp/";
      description = "URL to OpenTripPlanner instance";
    };
  };

  config = lib.mkIf cfg.enable {
    # Geocoding proxy service (Pelias-to-Nominatim translator)
    systemd.services.digitransit-geocoding = {
      description = "Digitransit Geocoding Proxy (Pelias-to-Nominatim)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        PORT = "3200";
        # Use local Nominatim via nginx proxy on port 8088
        NOMINATIM_URL = if config.services.nominatim.enable
          then "http://127.0.0.1:8088"
          else "https://nominatim.openstreetmap.org";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nodejs_20}/bin/node ${geocodingProxyScript}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
      };
    };

    systemd.services.digitransit = {
      description = "Digitransit Trip Planning UI";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "opentripplanner.service" "digitransit-geocoding.service" ];

      environment = {
        NODE_ENV = "production";
        CONFIG = "newyork";
        OTP_URL = cfg.otpUrl;
        PORT = toString cfg.port;
        # Use Caddy-proxied geocoding endpoint via Tailscale hostname
        GEOCODING_BASE_URL = "https://office-desktop.tail5ca7.ts.net/geocoding";
        # Use local tile server via Caddy proxy (translates HSL tile URLs to /hot/)
        MAP_URL = "https://office-desktop.tail5ca7.ts.net";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${digitransit-ui}/bin/digitransit-ui";
        Restart = "on-failure";
        RestartSec = "10s";
        DynamicUser = true;
        MemoryHigh = "1G";
        MemoryMax = "2G";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}

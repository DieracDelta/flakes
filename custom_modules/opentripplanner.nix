{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.opentripplanner;

  otpHome = "/var/lib/opentripplanner";

  # OpenTripPlanner shaded JAR - contains all dependencies
  opentripplanner = pkgs.stdenv.mkDerivation rec {
    pname = "opentripplanner";
    version = "2.8.1";

    src = pkgs.fetchurl {
      url = "https://github.com/opentripplanner/OpenTripPlanner/releases/download/v${version}/otp-shaded-${version}.jar";
      hash = "sha256-60Ikyw9Z7ZE+4kDReDgJGg5totgdghbDHAfFFQKDFpc=";
    };

    dontUnpack = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      mkdir -p $out/share/java $out/bin
      cp $src $out/share/java/otp-shaded-${version}.jar

      makeWrapper ${pkgs.jdk21}/bin/java $out/bin/otp \
        --add-flags "-Xmx${toString cfg.maxMemoryGb}G" \
        --add-flags "-jar $out/share/java/otp-shaded-${version}.jar"
    '';

    meta = with lib; {
      description = "Open source multi-modal trip planner";
      homepage = "https://www.opentripplanner.org/";
      license = licenses.lgpl3Plus;
      platforms = platforms.all;
      mainProgram = "otp";
    };
  };

  # Helper script to download GTFS feeds
  otp-download-gtfs = pkgs.writeShellApplication {
    name = "otp-download-gtfs";
    runtimeInputs = with pkgs; [
      wget
      curl
      jq
    ];
    text = ''
      # OTP scans the data directory for .zip files - put GTFS directly there
      count=0
      # shellcheck disable=SC2068
      for url in $@; do
        echo "Downloading GTFS feed: $url"
        # Use numbered filename with .zip extension (OTP auto-detects .zip files)
        filename="gtfs-feed-$count.zip"
        wget -O "${otpHome}/$filename" "$url"
        count=$((count + 1))
      done

      echo "GTFS feeds downloaded to ${otpHome}"
    '';
  };

  # Helper script to build OTP graph
  otp-build-graph = pkgs.writeShellApplication {
    name = "otp-build-graph";
    runtimeInputs = [ opentripplanner ];
    text = ''
      echo "Building OTP graph from data in ${otpHome}..."
      echo "This may take a while depending on data size."

      otp --build --save ${otpHome}

      echo "Graph build complete!"
    '';
  };

  # Build config JSON
  # Note: OSM files are auto-discovered from the data directory (*.osm.pbf)
  buildConfigFile = pkgs.writeText "build-config.json" (
    builtins.toJSON {
      # Transit data config
      transitFeeds = map (feed: {
        type = "gtfs";
        source = feed;
      }) cfg.gtfsFeeds;

      # Build settings
      areaVisibility = true;
      platformEntriesLinking = true;
      parentStopLinking = true;
      transitServiceStart = "-P1Y";
      transitServiceEnd = "P2Y";
    }
  );

  # Router config JSON
  routerConfigFile = pkgs.writeText "router-config.json" (
    builtins.toJSON (
      {
        updaters = [ ];
        routingDefaults = {
          walkSpeed = 1.3;
          bikeSpeed = 5.0;
          carSpeed = 15.0;
          numItineraries = 6;
        };
      }
      // cfg.routerConfig
    )
  );

in
{
  options = {
    services.opentripplanner = {
      enable = lib.mkEnableOption "OpenTripPlanner multi-modal trip planner";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for the OTP web server";
      };

      maxMemoryGb = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Maximum JVM heap size in GB";
      };

      osmDataPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = "/var/lib/renderd_share/map-data.osm.pbf";
        description = ''
          Path to OSM data file (.osm.pbf).
          Defaults to the map data from openstreetmap service.
          Set to null if using osmUrls instead.
        '';
      };

      osmUrls = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "https://download.geofabrik.de/north-america/us/new-york-latest.osm.pbf"
          "https://download.geofabrik.de/north-america/us/connecticut-latest.osm.pbf"
        ];
        description = ''
          OSM data URLs to download. If multiple URLs are provided,
          they will be merged using osmium-tool.
        '';
      };

      gtfsFeeds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "https://gtfs.example.com/agency.zip"
          "/var/lib/opentripplanner/gtfs/local-transit.zip"
        ];
        description = ''
          List of GTFS feed URLs or local paths.
          Get GTFS feeds from https://transitfeeds.com/ or your local transit agency.
        '';
      };

      gtfsUrls = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "https://gtfs.example.com/feed.zip" ];
        description = ''
          GTFS feed URLs to download during setup.
          These will be downloaded to ${otpHome}/gtfs/
        '';
      };

      routerConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional router configuration (merged with defaults)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.extraGroups.otp = { };
    users.extraUsers.otp = {
      isSystemUser = true;
      description = "OpenTripPlanner Service User";
      group = "otp";
      home = otpHome;
      createHome = true;
      packages = [
        opentripplanner
        otp-download-gtfs
        otp-build-graph
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${otpHome} 0755 otp otp"
    ];

    # Setup service - downloads GTFS and builds graph
    systemd.services.opentripplanner-setup = {
      description = "OpenTripPlanner Graph Builder";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "openstreetmap-setup.service"
      ];
      wants = [ "network-online.target" ];

      path = [
        opentripplanner
        otp-download-gtfs
        pkgs.wget
        pkgs.osmium-tool
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "otp";
        WorkingDirectory = otpHome;
      };

      script = ''
        STATE_FILE="${otpHome}/.setup-complete"
        if [ -f "$STATE_FILE" ]; then
          echo "OTP setup already completed, skipping"
          exit 0
        fi

        echo "Starting OpenTripPlanner setup..."

        # Copy config files (remove first since Nix store copies are read-only)
        rm -f ${otpHome}/build-config.json ${otpHome}/router-config.json
        install -m 644 ${buildConfigFile} ${otpHome}/build-config.json
        install -m 644 ${routerConfigFile} ${otpHome}/router-config.json

        # Download GTFS feeds if URLs provided
        ${lib.optionalString (cfg.gtfsUrls != [ ]) ''
          echo "Downloading GTFS feeds..."
          otp-download-gtfs ${lib.concatStringsSep " " cfg.gtfsUrls}
        ''}

        # Get OSM data
        ${
          if cfg.osmUrls != [ ] then
            ''
              echo "Downloading OSM data files..."
              OSM_FILES=""
              count=0
              for url in ${lib.concatStringsSep " " cfg.osmUrls}; do
                filename="${otpHome}/osm-download-$count.osm.pbf"
                echo "Downloading: $url"
                wget -O "$filename" "$url"
                OSM_FILES="$OSM_FILES $filename"
                count=$((count + 1))
              done

              if [ $count -eq 1 ]; then
                # Single file, just rename
                mv ${otpHome}/osm-download-0.osm.pbf ${otpHome}/osm-data.osm.pbf
              else
                # Multiple files, merge with osmium
                echo "Merging $count OSM files..."
                osmium merge $OSM_FILES -o ${otpHome}/osm-data.osm.pbf --overwrite
                # Clean up individual files
                rm -f ${otpHome}/osm-download-*.osm.pbf
              fi
              echo "OSM data ready: ${otpHome}/osm-data.osm.pbf"
            ''
          else if cfg.osmDataPath != null then
            ''
              # Check if OSM data exists
              if [ ! -f "${cfg.osmDataPath}" ]; then
                echo "ERROR: OSM data not found at ${cfg.osmDataPath}"
                echo "Make sure openstreetmap service has completed setup first."
                exit 1
              fi

              # Copy OSM data into OTP directory
              cp "${cfg.osmDataPath}" "${otpHome}/osm-data.osm.pbf"
              echo "Copied OSM data: ${cfg.osmDataPath} -> ${otpHome}/osm-data.osm.pbf"
            ''
          else
            ''
              echo "ERROR: No OSM data configured (set osmDataPath or osmUrls)"
              exit 1
            ''
        }

        # Build the graph
        echo "Building routing graph (this may take a while)..."
        otp --build --save ${otpHome}

        touch "$STATE_FILE"
        echo "OTP setup complete!"
      '';
    };

    # Main OTP service
    systemd.services.opentripplanner = {
      description = "OpenTripPlanner Trip Planning Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "opentripplanner-setup.service" ];
      requires = [ "opentripplanner-setup.service" ];

      serviceConfig = {
        Type = "simple";
        User = "otp";
        WorkingDirectory = otpHome;
        ExecStart = "${opentripplanner}/bin/otp --load --serve --port ${toString cfg.port} ${otpHome}";
        Restart = "on-failure";
        RestartSec = "10s";

        # Resource limits
        MemoryHigh = "${toString cfg.maxMemoryGb}G";
        MemoryMax = "${toString (cfg.maxMemoryGb + 1)}G";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}

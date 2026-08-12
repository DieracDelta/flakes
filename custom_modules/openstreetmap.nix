{
  config,
  pkgs,
  lib,
  ...
}:

let

  cfg = config.services.openstreetmap;

  renderdHome = "/var/lib/renderd";
  renderdShare = "/var/lib/renderd_share";
  renderdSocket = "${renderdShare}/renderd.sock";
  tileDir = "${renderdShare}/tiles";

  osm-carto = pkgs.fetchFromGitHub {
    owner = "gravitystorm";
    repo = "openstreetmap-carto";
    rev = "34af2a9586914baa70ebe19de032a9804eddc787"; # 2025-12-28
    sha256 = "sha256-CQobgi9/ceq0Z/NAHnsK0Nf+hIzFG1WOHJodDjmC88U=";
  };

  mapnik-carto =
    let
      env = {
        nativeBuildInputs = [ pkgs.carto ];
      };
    in
    pkgs.runCommand "mapnik-carto" env ''
      mkdir $out
      cd $out
      cp -r ${osm-carto}/* .
      carto --file mapnik.xml project.mml
    '';

  osm2pgsql-runner = pkgs.writeShellApplication {
    name = "osm-osm2pgsql-runner";
    runtimeInputs = with pkgs; [
      osm2pgsql
      postgresql
      procps
      gawk
    ];
    text = ''
      cores=$(nproc)
      mem=$(($(free -m | awk '/^Mem:/{print $2}') * 3 / 4))
      echo "Running with $cores cores and $mem MB of RAM"

      # shellcheck disable=SC2068
      osm2pgsql \
        --database=gis \
        --output=flex \
        "--style=${osm-carto}/openstreetmap-carto-flex.lua" \
        "--cache=$mem" \
        "--number-processes=$cores" \
        --flat-nodes=nodes.cache \
        $@

      # Load database functions and indexes
      psql -d gis -f ${osm-carto}/functions.sql
      psql -d gis -f ${osm-carto}/indexes.sql
    '';
  };

  osm-carto-get-external-data = pkgs.writeShellApplication {
    name = "osm-get-external-data";
    runtimeInputs = with pkgs; [
      (python3.withPackages (
        p: with p; [
          pyaml
          requests
          psycopg2
        ]
      ))
      gdal
    ];
    text = ''
      ${osm-carto}/scripts/get-external-data.py \
        --config ${osm-carto}/external-data.yml
    '';
  };

  osm-carto-get-fonts = pkgs.writeShellApplication {
    name = "osm-get-fonts";
    runtimeInputs = with pkgs; [
      (python3.withPackages (p: [ p.requests ]))
    ];
    text = ''
      cd ${renderdShare}
      python3 ${osm-carto}/scripts/get-fonts.py
    '';
  };

  # https://lists.openstreetmap.org/pipermail/dev/2017-January/029662.html
  # "Higher zooms (12+) typically take about 1 second per 8x8 metatile per
  # CPU thread. 15+ tiles are not pre-rendered for the world, they are
  # rendered on demand and cached. The OSMF pre-renders z0-z12 tiles, and it
  # takes about a day to do this."
  osm-prerender-everything = pkgs.writeShellApplication {
    name = "osm-prerender-everything";
    runtimeInputs = [ mod_tile ];
    text = ''
      # shellcheck disable=SC2068
      render_list \
        --socket=${renderdSocket} \
        --tile-dir=${tileDir} \
        --map=s2o \
        --all \
        --force \
        --num-threads=${builtins.toString cfg.threads} \
        $@
    '';
  };

  renderdConfigFile = pkgs.writeText "renderd.conf" ''
    [mapnik]
    font_dir_recurse=true
    font_dir=${renderdShare}/fonts
    plugins_dir=${pkgs.mapnik}/lib/mapnik/input

    [renderd]
    pid_file=${renderdShare}/renderd.pid
    stats_file=${renderdShare}/renderd1.stats
    socketname=${renderdSocket}
    num_threads=${builtins.toString cfg.threads}
    tile_dir=${tileDir}

    [s2o]
    HOST=localhost
    MAXZOOM=${builtins.toString cfg.maxZoom}
    TILEDIR=${tileDir}
    TILESIZE=256
    URI=/hot/
    XML=${mapnik-carto}/mapnik.xml
  '';

  inherit (pkgs.apacheHttpdPackages) mod_tile;

  # Inline wwwroot - Leaflet map viewer
  wwwroot = pkgs.writeTextDir "index.html" ''
    <html>
      <head>
        <title>OpenStreetMap on NixOS</title>
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
      </head>
      <body>
        <div id="map" style="width: 100vw; height: 100vh;"></div>
        <script>
          const start_coordinates = [43.7384, 7.4246]; // Monaco
          const start_zoomlevel = 13;
          const map = L.map('map').setView(start_coordinates, start_zoomlevel);
          const tiles = L.tileLayer('hot/{z}/{x}/{y}.png', { maxZoom: 19, }).addTo(map);
        </script>
      </body>
    </html>
  '';

in
{
  options = {
    services.openstreetmap = {
      enable = lib.mkEnableOption "openstreetmap hosting";
      debug = lib.mkEnableOption "debug outputs in journal";
      threads = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Number of threads to use for parallelizable tasks";
      };
      maxZoom = lib.mkOption {
        type = lib.types.int;
        default = 20;
        description = "Maximum zoom level";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 80;
        description = "Port to serve the tiles over HTTP on";
      };
      totalRamGb = lib.mkOption {
        type = lib.types.int;
        description = "Amount of RAM available on the machine. Will be used for DB tuning settings";
      };
      mapDataUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "https://download.geofabrik.de/europe/monaco-latest.osm.pbf";
        example = "https://download.geofabrik.de/north-america/us-latest.osm.pbf";
        description = ''
          URL to download OSM map data from (e.g., from geofabrik.de).
          Set to null to skip automatic map data download/import.
          Ignored if mapDataPath is set.

          For full planet data (WARNING: ~70GB download, days to import):
          https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf
        '';
      };
      mapDataPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression ''
          pkgs.fetchurl {
            url = "https://download.geofabrik.de/europe/monaco-latest.osm.pbf";
            sha256 = "sha256-XXXX...";
          }
        '';
        description = ''
          Pre-fetched map data file (Nix derivation or path).
          If set, this is used instead of downloading from mapDataUrl.
          Provides reproducibility and caching via Nix store.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.extraGroups.renderd = { };
    users.extraUsers.renderd = {
      isNormalUser = true;
      description = "Renderd Service User";
      group = "renderd";
      createHome = true;
      home = "/var/lib/renderd";
      packages = [
        osm2pgsql-runner
        osm-carto-get-fonts
        osm-carto-get-external-data
        osm-prerender-everything
        pkgs.wget
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${renderdShare} 0755 renderd renderd"
      "d ${tileDir} 0755 renderd renderd"
    ];

    systemd.services.renderd = {
      description = "RenderD Daemon";
      wantedBy = [ "multi-user.target" ];
      before = [ "httpd.service" ];
      after = [
        "openstreetmap-db-init.service"
        "openstreetmap-setup.service"
      ];
      wants = [
        "postgresql.service"
        "openstreetmap-db-init.service"
        "openstreetmap-setup.service"
      ];
      serviceConfig = {
        ExecStart = "${mod_tile}/bin/renderd --config ${renderdConfigFile} --foreground";
        StateDirectory = "renderd";
        User = "renderd";
        WorkingDirectory = renderdShare;
        MemoryHigh = "${builtins.toString cfg.totalRamGb}G";
        MemoryMax = "${builtins.toString cfg.totalRamGb}G";
      };
      environment = lib.optionalAttrs cfg.debug {
        G_MESSAGES_DEBUG = "all";
      };
    };

    # Automatic setup service - downloads map data, imports to PostGIS, gets fonts
    systemd.services.openstreetmap-setup =
      lib.mkIf (cfg.mapDataPath != null || cfg.mapDataUrl != null)
        {
          description = "OpenStreetMap Initial Data Setup";
          wantedBy = [ "multi-user.target" ];
          after = [
            "postgresql.service"
            "network-online.target"
            "openstreetmap-db-init.service"
          ];
          requires = [ "openstreetmap-db-init.service" ];
          wants = [ "network-online.target" ];

          path = [
            osm2pgsql-runner
            osm-carto-get-fonts
            osm-carto-get-external-data
            pkgs.wget
            pkgs.systemd
          ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "renderd";
            WorkingDirectory = renderdShare;
          };

          script =
            let
              # Use Nix path if provided, otherwise download from URL
              mapDataSource = if cfg.mapDataPath != null then cfg.mapDataPath else null;
            in
            ''
              STATE_FILE="${renderdShare}/.setup-complete"
              if [ -f "$STATE_FILE" ]; then
                echo "Setup already completed, skipping"
                exit 0
              fi

              echo "Starting OpenStreetMap setup..."

              # Get map data
              MAP_FILE="${renderdShare}/map-data.osm.pbf"
              if [ ! -f "$MAP_FILE" ]; then
                ${
                  if mapDataSource != null then
                    ''
                      echo "Using Nix-managed map data from ${mapDataSource}..."
                      cp "${mapDataSource}" "$MAP_FILE"
                    ''
                  else
                    ''
                      echo "Downloading map data from ${cfg.mapDataUrl}..."
                      wget -O "$MAP_FILE" "${cfg.mapDataUrl}"
                    ''
                }
              fi

              # Import to PostGIS
              echo "Importing map data to PostGIS (this may take a while)..."
              osm-osm2pgsql-runner "$MAP_FILE"

              # Get fonts
              echo "Downloading fonts..."
              osm-get-fonts

              # Get external data (shapefiles)
              echo "Downloading external data..."
              osm-get-external-data

              # Mark setup complete
              touch "$STATE_FILE"
              echo "Setup complete!"
            '';
        };

    services.postgresql = {
      enable = true;
      extensions = ps: [ ps.postgis ];

      # Declarative - merges with existing databases (atuin, hydra)
      ensureDatabases = [ "gis" ];
      ensureUsers = [
        {
          name = "renderd";
          # Note: can't use ensureDBOwnership because db is "gis" not "renderd"
          # Permissions granted in openstreetmap-db-init service
        }
      ];

      # These settings MERGE with existing, not override
      settings =
        let
          quarterOfTotalMbs = cfg.totalRamGb * 1024 / 4;
          mbStr = x: "${builtins.toString x}MB";
        in
        {
          shared_buffers = mbStr quarterOfTotalMbs;
          work_mem = "256MB";
          checkpoint_timeout = "10min";
          max_wal_size = "2GB";
        };
    };

    # Initialize PostGIS extensions (runs AFTER ensureDatabases creates the db)
    systemd.services.openstreetmap-db-init = {
      description = "Initialize OpenStreetMap PostGIS database";
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      before = [
        "openstreetmap-setup.service"
        "renderd.service"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
      };

      script = ''
        set -euo pipefail

        # Wait for gis database to exist (ensureDatabases creates it)
        for i in $(seq 1 30); do
          if psql -lqt | cut -d \| -f 1 | grep -qw gis; then
            break
          fi
          echo "Waiting for gis database..."
          sleep 1
        done

        # Check if PostGIS already initialized
        if psql -d gis -c "SELECT 1 FROM pg_extension WHERE extname='postgis'" -tAq 2>/dev/null | grep -q 1; then
          echo "PostGIS already initialized, skipping"
          exit 0
        fi

        echo "Initializing PostGIS extensions..."
        psql -d gis <<'EOSQL'
          CREATE EXTENSION IF NOT EXISTS hstore;
          CREATE EXTENSION IF NOT EXISTS postgis;

          -- Make renderd the owner of gis database
          ALTER DATABASE gis OWNER TO renderd;

          -- Grant permissions to renderd
          GRANT ALL ON ALL TABLES IN SCHEMA public TO renderd;
          GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO renderd;
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO renderd;
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO renderd;
        EOSQL

        echo "PostGIS initialization complete"
      '';

      path = [ config.services.postgresql.package ];
    };

    services.httpd = {
      enable = true;
      extraModules = [
        {
          name = "tile";
          path = "${mod_tile}/modules/mod_tile.so";
        }
      ];
      virtualHosts = {
        "tileserver" = {
          documentRoot = wwwroot;
          listen = [ { inherit (cfg) port; } ];
          extraConfig = ''
            LoadTileConfigFile ${renderdConfigFile}
            ModTileTileDir ${tileDir}
            ModTileRenderdSocketName ${renderdSocket}

            ModTileEnableStats On
            ModTileRequestTimeout 300
            ModTileMissingRequestTimeout 300
            ModTileMaxLoadOld 16
            ModTileMaxLoadMissing 50

            ModTileCacheDurationMax 604800
            ModTileCacheDurationDirty 90000000
            ModTileCacheDurationMinimum 108000
            ModTileCacheDurationMediumZoom 13 86400
            ModTileCacheDurationLowZoom 9 518400
            ModTileCacheLastModifiedFactor 0.20
            ModTileEnableTileThrottling Off
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}

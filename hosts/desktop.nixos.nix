{
  config,
  pkgs,
  lib,
  ...
}:

{

  nix.settings.allowed-users = [
    "jrestivo"
    "siraben"
    "jachym"
    "faye"
    "john"
  ];
  nix.settings.trusted-users = [
    "jrestivo"
    "siraben"
    "jachym"
    "faye"
    "john"
  ];
  imports = [ ./hw/desktop.nix ];

  custom_modules.jellyfin.enable = true;
  custom_modules.nextcloud.enable = false;
  custom_modules.core_services.enable = true;
  custom_modules.workstation_services.enable = true;
  custom_modules.rust-filehost.enable = false;
  custom_modules.hydra.enable = true;
  custom_modules.yubikey.enable = true;
  custom_modules.container_configs.enable = false;
  custom_modules.bens_config.enable = true;
  custom_modules.network_monitor.enable = true;
  custom_modules.nethog_monitor.enable = true;
  custom_modules.monitoring.enable = true;
  custom_modules.monitoring.enableUps = true;
  custom_modules.monitoring.enableGpu = true;
  custom_modules.comfyui.enable = true;
  custom_modules.actual.enable = true;
  custom_modules.dns.enable = true;
  custom_modules.taskwarrior.enable = true;

  # wger workout/nutrition tracker with micronutrient support
  custom_modules.wger = {
    enable = true;
    allowedHosts = [ "localhost" "127.0.0.1" "office-desktop.tail5ca7.ts.net" ];
    trustedOrigins = [ "https://office-desktop.tail5ca7.ts.net" ];
    siteUrl = "https://office-desktop.tail5ca7.ts.net/wger";
    adminUser = "admin";
    adminEmail = "admin@localhost";
    adminPasswordFile = "/var/lib/wger/admin-password";
  };

  # Koito scrobbler - integrates with Navidrome
  custom_modules.koito = {
    enable = true;
    port = 4110;
    allowedHosts = "office-desktop.tail5ca7.ts.net,localhost,127.0.0.1,127.0.0.1:4110";
    configureNavidrome = true; # Will be auto-disabled when multi-scrobbler is enabled
    # Subsonic artwork from Navidrome
    subsonicUrl = "http://127.0.0.1:4533/navidrome";
    subsonicParamsFile = "/var/lib/koito/secrets.env";
  };

  # Multi-scrobbler - forwards scrobbles from Navidrome to multiple services
  custom_modules.multi-scrobbler = {
    enable = true;
    port = 9078;
    baseUrl = "https://office-desktop.tail5ca7.ts.net/scrobbler";
  };

  services.openstreetmap = {
    enable = true;
    totalRamGb = 16;
    port = 8083;
    threads = 4;
    debug = true;
    # New York state - covers NYC metro area and Metro-North stations
    mapDataUrl = "https://download.geofabrik.de/north-america/us/new-york-latest.osm.pbf";
  };

  # OpenTripPlanner for multi-modal transit routing
  services.opentripplanner = {
    enable = true;
    port = 8084;
    maxMemoryGb = 8; # Larger region needs more memory
    # OSM data for NY + CT (downloaded and merged by OTP setup)
    osmDataPath = null; # Don't use openstreetmap service data
    osmUrls = [
      "https://download.geofabrik.de/north-america/us/new-york-latest.osm.pbf"
      "https://download.geofabrik.de/north-america/us/connecticut-latest.osm.pbf"
    ];
    # GTFS feeds for NY/CT transit
    gtfsUrls = [
      # NYC Subway
      "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip"
      # Metro-North Railroad (NYC to CT/Upstate NY commuter rail)
      "https://rrgtfsfeeds.s3.amazonaws.com/gtfsmnr.zip"
      # CT Transit (Hartford, New Haven, Stamford, etc.)
      "https://www.cttransit.com/sites/default/files/gtfs/googlect_transit.zip"
    ];
  };

  # Digitransit production UI for trip planning
  services.digitransit = {
    enable = true;
    port = 8085;
    otpUrl = "http://localhost:8084/otp/";
  };

  # Self-hosted Nominatim geocoding for Digitransit
  services.nominatim = {
    enable = true;
    hostName = "nominatim.local";
    settings = {
      NOMINATIM_IMPORT_STYLE = "full";
    };
  };
  services.nginx.virtualHosts."nominatim.local" = {
    listen = [
      {
        addr = "127.0.0.1";
        port = 8088;
      }
    ];
    enableACME = false;
    forceSSL = false;
  };

  programs.noisetorch.enable = false;

}

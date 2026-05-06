{
  config,
  pkgs,
  lib,
  system,
  nixpkgs-master,
  ...
}:
let
  ollamaMasterPkgs = import nixpkgs-master {
    inherit system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = [ "8.9" ];
    };
  };
  forgejoDomain = "office-desktop.tail5ca7.ts.net";
  forgejoBasePath = "/forgejo";
  forgejoPort = 3010;
in
{

  nix.settings.allowed-users = [
    "jrestivo"
    "gitea-runner"
    "siraben"
    "jachym"
    "faye"
    "john"
  ];
  nix.settings.trusted-users = [
    "jrestivo"
    "gitea-runner"
    "siraben"
    "jachym"
    "faye"
    "john"
  ];
  imports = [ ./hw/desktop.nix ];

  custom_modules.music.enable = true;
  custom_modules.paperless.enable = false;
  custom_modules.nextcloud.enable = false;
  custom_modules.core_services.enable = true;
  custom_modules.workstation_services.enable = true;
  custom_modules.rust-filehost.enable = false;
  custom_modules.hydra.enable = false;
  custom_modules.yubikey.enable = true;
  custom_modules.trezor.enable = true;
  custom_modules.rotki.enable = true;
  custom_modules.container_configs.enable = false;
  custom_modules.bens_config.enable = true;
  custom_modules.network_monitor.enable = true;
  custom_modules.network_monitor.enableNtopng = false;
  custom_modules.nethog_monitor.enable = true;
  custom_modules.monitoring.enable = true;
  custom_modules.monitoring.enableUps = true;
  custom_modules.monitoring.enableGpu = true;
  custom_modules.comfyui.enable = true;
  custom_modules.actual.enable = true;
  custom_modules.dns.enable = true;
  custom_modules.taskwarrior.enable = true;
  custom_modules.calendar.enable = true;
  custom_modules.runner_vms.enable = true;
  custom_modules.soulseek = {
    enable = true;
    tailscaleExitNode = "100.109.204.162";
  };
  custom_modules.plane = {
    enable = true;
    domain = "office-desktop.tail5ca7.ts.net";
    basePath = "/plane";
  };
  custom_modules.borgbackup = {
    enable = true;
    repos = {
      local = {
        path = "/storage/backups/borg/forgejo-plane";
        startAt = "*-*-* 04:00:00";
      };
      arm-vps = {
        path = "borg@100.104.74.94:.";
        sshKey = "/root/.ssh/borg_ed25519";
        startAt = "*-*-* 04:30:00";
      };
      beelink = {
        path = "jrestivo@100.85.199.123:borg/desktop";
        sshKey = "/root/.ssh/borg_ed25519";
        startAt = "*-*-* 05:00:00";
      };
    };
  };

  programs.bpftop.enable = true;
  # services.nix-btm.enable = false;
  services.shapebpf.enable = true;
  services.shapebpf.interface = "enp6s0";
  systemd.services.shapebpf.environment.RUST_LOG = lib.mkForce "error";
  services.ollama.package = ollamaMasterPkgs.ollama-cuda;
  users.users.jrestivo.extraGroups = [
    "forgejo"
    "shapebpf"
  ];
  users.groups.gitea-runner = { };
  users.users.gitea-runner = {
    isSystemUser = true;
    group = "gitea-runner";
    extraGroups = [ "docker" ];
    home = "/var/cache/forgejo-actions/runner";
    createHome = true;
  };

  services.forgejo = {
    enable = true;
    stateDir = "/var/lib/forgejo";

    database = {
      type = "postgres";
    };

    lfs.enable = true;

    dump = {
      enable = true;
      interval = "03:45";
      backupDir = "/var/lib/forgejo/dump";
      type = "tar.zst";
      age = "8w";
    };

    settings = {
      DEFAULT = {
        APP_NAME = "Forgejo";
      };

      server = {
        DOMAIN = forgejoDomain;
        ROOT_URL = "https://${forgejoDomain}${forgejoBasePath}/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = forgejoPort;
        DISABLE_SSH = false;
        SSH_DOMAIN = forgejoDomain;
        SSH_PORT = 22;
      };

      session = {
        COOKIE_NAME = "forgejo_session";
        COOKIE_SECURE = true;
      };

      service = {
        DISABLE_REGISTRATION = false;
        REQUIRE_SIGNIN_VIEW = true;
      };

      mirror = {
        ENABLED = true;
        DEFAULT_INTERVAL = "8h";
        MIN_INTERVAL = "10m";
      };

      migrations = {
        ALLOWED_DOMAINS = "beelink.tail09906.ts.net";
      };

      repository = {
        DEFAULT_REPO_UNITS = "repo.code,repo.releases,repo.issues,repo.pulls,repo.wiki,repo.projects,repo.packages,repo.actions";
      };

      "repository.pull-request" = {
        DEFAULT_MERGE_STYLE = "rebase";
      };

      actions = {
        ENABLED = true;
      };
    };
  };

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.desktop = {
      enable = true;
      name = "desktop";
      url = "http://127.0.0.1:${toString forgejoPort}";
      tokenFile = "/var/lib/forgejo/runner_token";
      labels = [
        "native:host"
        "ubuntu-latest:host"
        "ubuntu-22.04:host"
        "debian-latest:host"
      ];
      hostPackages = with pkgs; [
        bash
        coreutils
        curl
        findutils
        gawk
        gitMinimal
        gnused
        jq
        nix
        nodejs
        util-linux
        wget
      ];
      settings.log = {
        level = "debug";
        job_level = "debug";
      };
      settings.runner.capacity = 12;
      settings.container = {
        docker_host = "-";
        force_pull = false;
        force_rebuild = false;
        options = "--volume psi-code-nix:/nix";
        workdir_parent = "/var/cache/forgejo-actions/work";
        valid_volumes = [ "psi-code-nix" ];
      };
      settings.host.workdir_parent = "/var/cache/forgejo-actions/work";
      settings.cache = {
        enabled = true;
        dir = "/var/cache/forgejo-actions/runner/actcache";
      };
    };
    instances.desktop-docker = {
      enable = true;
      name = "desktop-docker";
      url = "http://127.0.0.1:${toString forgejoPort}";
      tokenFile = "/var/lib/forgejo/runner_token";
      labels = [
        "docker:docker://docker.io/nixos/nix:latest"
      ];
      hostPackages = with pkgs; [
        bash
        coreutils
        curl
        findutils
        gawk
        gitMinimal
        gnused
        jq
        nix
        nodejs
        util-linux
        wget
      ];
      settings.log = {
        level = "debug";
        job_level = "debug";
      };
      settings.runner.capacity = 12;
      settings.container = {
        docker_host = "unix:///run/docker.sock";
        force_pull = false;
        force_rebuild = false;
        network = "host";
        options = "--volume psi-code-nix:/nix";
        workdir_parent = "/var/cache/forgejo-actions/work";
        valid_volumes = [ "psi-code-nix" ];
      };
      settings.host.workdir_parent = "/var/cache/forgejo-actions/work";
      settings.cache = {
        enabled = true;
        dir = "/var/cache/forgejo-actions/runner/actcache";
      };
    };
  };

  systemd.services.gitea-runner-desktop = {
    environment.HOME = lib.mkForce "/var/cache/forgejo-actions/runner";
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "gitea-runner";
      Group = "gitea-runner";
      WorkingDirectory = lib.mkForce "/var/lib/gitea-runner/desktop";
      ReadWritePaths = [
        "/var/cache/forgejo-actions"
        "/var/tmp"
      ];
    };
  };
  systemd.services."gitea-runner-desktop\\x2ddocker" = {
    environment.HOME = lib.mkForce "/var/cache/forgejo-actions/runner";
    after = [ "docker-volume-psi-code-nix.service" ];
    requires = [ "docker-volume-psi-code-nix.service" ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "gitea-runner";
      Group = "gitea-runner";
      WorkingDirectory = lib.mkForce "/var/lib/gitea-runner/desktop-docker";
      ReadWritePaths = [
        "/var/cache/forgejo-actions"
        "/var/tmp"
      ];
    };
  };
  systemd.services.docker-volume-psi-code-nix = {
    description = "Create persistent Docker volume for psi-code CI Nix store";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.docker}/bin/docker volume create --label forgejo-ci=psi-code --label keep=true psi-code-nix";
    };
  };
  systemd.tmpfiles.rules = [
    "a+ /home/jrestivo - - - - u:gitea-runner:--x"
    "Z /var/lib/gitea-runner 0755 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/runner 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/runner/actcache 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/work 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/cargo-home 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/cargo-target 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/frontend-cargo-target 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/lake 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/next 0775 gitea-runner gitea-runner -"
  ];

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "daily";
      flags = [
        "--all"
        "--filter=until=24h"
      ];
    };
  };

  services.caddy.virtualHosts."${forgejoDomain}".extraConfig = lib.mkBefore ''

    redir ${forgejoBasePath} ${forgejoBasePath}/ permanent
    handle_path ${forgejoBasePath}/* {
      reverse_proxy 127.0.0.1:${toString forgejoPort}
    }
  '';

  services.homepage-dashboard.services = lib.mkAfter [
    {
      "Development" = [
        {
          "Forgejo" = {
            icon = "forgejo";
            href = "${forgejoBasePath}/";
            description = "Self-hosted Git forge";
          };
        }
        {
          "Plane" = {
            icon = "plane";
            href = "/plane/";
            description = "Project management";
          };
        }
      ];
    }
  ];

  # wger workout/nutrition tracker with micronutrient support
  custom_modules.wger = {
    enable = false;
    allowedHosts = [
      "localhost"
      "127.0.0.1"
      "office-desktop.tail5ca7.ts.net"
    ];
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
    enable = false;
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
    enable = false;
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

  environment.systemPackages = with pkgs; [
    linear-cli
    agent-deck
    codex
    forgejo-mcp
    plane-mcp-server
  ];

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

  # Prevent OOM - earlyoom kills processes before system becomes unresponsive
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
  };

}

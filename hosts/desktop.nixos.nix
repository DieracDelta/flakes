{
  config,
  pkgs,
  lib,
  inputs,
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
  forgejoMcpPort = 8213;
  forgejoMcpTokenFile = "/home/jrestivo/FOREJO_TOKEN";
  forgejoRunnerCapacity = 12;
  forgejoRunnerCpuQuota = "800%";
  forgejoRunnerAllowedCPUs = "0-7";
  forgejoRunnerMemoryHigh = "24G";
  forgejoRunnerMemoryMax = "32G";
  forgejoRunnerNixConfig = "build-users-group =";
  forgejoDockerJobOptions = "--cpus=8 --cpuset-cpus=0-7 --memory=12g --memory-swap=12g --env \"NIX_CONFIG=${forgejoRunnerNixConfig}\" --volume psi-code-nix:/nix";
  forgejoActionsCachePrune = pkgs.writeShellScript "forgejo-actions-cache-prune" ''
    set -euo pipefail

    prune_dirs_older_than() {
      local cache_dir="$1"
      local age="$2"

      if [ ! -d "$cache_dir" ]; then
        return 0
      fi

      ${pkgs.fd}/bin/fd \
        --hidden \
        --no-ignore \
        --type directory \
        --exact-depth 1 \
        --changed-before "$age" \
        . "$cache_dir" \
        -X ${pkgs.coreutils}/bin/rm -rf --
    }

    prune_entries_older_than() {
      local cache_dir="$1"
      local age="$2"

      if [ ! -d "$cache_dir" ]; then
        return 0
      fi

      ${pkgs.fd}/bin/fd \
        --hidden \
        --no-ignore \
        --exact-depth 1 \
        --changed-before "$age" \
        . "$cache_dir" \
        -X ${pkgs.coreutils}/bin/rm -rf --
    }

    prune_dirs_older_than /var/tmp/ironmain-ci-work 1d

    for cache_root in \
      /var/cache/forgejo-actions/ironmain \
      /home/jrestivo/.cache/ironmain-ci; do
      prune_dirs_older_than "$cache_root/cargo-crap-target" 1d
      prune_entries_older_than "$cache_root/tmp" 1d

      for cache_dir in \
        "$cache_root/cargo-target" \
        "$cache_root/frontend-cargo-target" \
        "$cache_root/isa-metadata-cargo-target" \
        "$cache_root/fuzz-target" \
        "$cache_root/lake" \
        "$cache_root/next" \
        "$cache_root/test-projects" \
        "$cache_root/validation-target"; do
        prune_dirs_older_than "$cache_dir" 7d
      done
    done
  '';
  forgejoNixosTestSwitch = pkgs.callPackage ../nix/packages/forgejo-nixos-test-switch.nix { };
  forgejoMcpDaemon = pkgs.writeShellScript "forgejo-mcp-daemon" ''
    set -euo pipefail

    export FORGEJO_ACCESS_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/forgejo_token")"
    exec ${pkgs.forgejo-mcp}/bin/forgejo-mcp \
      --transport http \
      --http-port ${toString forgejoMcpPort} \
      --url http://127.0.0.1:${toString forgejoPort}
  '';
  leanMcpBin = "/home/jrestivo/dev/lean-lsp-mcp/.venv/bin/lean-lsp-mcp";
  leanMcpPort = 8212;
  leanMcpPath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.git
    pkgs.gnumake
    pkgs.nix
    pkgs.which
  ] + ":/home/jrestivo/.elan/bin:/home/jrestivo/.local/bin:/run/current-system/sw/bin";
  signalCliHermesDaemon = pkgs.writeShellScript "signal-cli-hermes-daemon" ''
    set -euo pipefail

    if [ -z "''${SIGNAL_ACCOUNT:-}" ]; then
      echo "SIGNAL_ACCOUNT is required. Set it in /home/jrestivo/.config/hermes/signal-cli-daemon.env" >&2
      exit 1
    fi

    exec ${pkgs.signal-cli}/bin/signal-cli \
      --config "''${SIGNAL_CLI_CONFIG:-/home/jrestivo/.local/share/signal-cli}" \
      --account "$SIGNAL_ACCOUNT" \
      daemon \
      --http "''${SIGNAL_HTTP_BIND:-127.0.0.1:18080}"
  '';
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
  custom_modules.comfyui.enable = false;
  custom_modules.actual.enable = true;
  custom_modules.jitsi-skynet.enable = true;
  custom_modules.dns.enable = true;
  custom_modules.taskwarrior.enable = true;
  custom_modules.calendar.enable = true;
  custom_modules.runner_vms.enable = true;
  custom_modules.octo-fiesta = {
    enable = true;
    subsonicUrl = "http://127.0.0.1:4533/navidrome";
    musicDir = /var/lib/musiclibrary;
    caddy = {
      basePath = "/octo-fiesta";
    };
  };
  custom_modules.soulseek = {
    enable = true;
    tailscaleExitNode = "100.109.204.162";
  };
  custom_modules.plane = {
    enable = true;
    domain = "office-desktop.tail5ca7.ts.net";
    basePath = "/plane";
    port = 8085;
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
  systemd.services.signal-cli-hermes = {
    description = "signal-cli HTTP daemon for Hermes Agent";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    unitConfig.ConditionPathExists = "/home/jrestivo/.config/hermes/signal-cli-daemon.env";

    environment = {
      HOME = "/home/jrestivo";
      SIGNAL_CLI_CONFIG = "/home/jrestivo/.local/share/signal-cli";
      SIGNAL_HTTP_BIND = "127.0.0.1:18080";
    };

    serviceConfig = {
      User = "jrestivo";
      EnvironmentFile = "/home/jrestivo/.config/hermes/signal-cli-daemon.env";
      ExecStart = signalCliHermesDaemon;
      Restart = "on-failure";
      RestartSec = "10s";
      WorkingDirectory = "/home/jrestivo";
    };
  };
  systemd.services.forgejo-mcp = {
    description = "Shared Forgejo MCP server";
    wantedBy = [ "multi-user.target" ];
    after = [
      "forgejo.service"
      "network.target"
    ];
    requires = [ "forgejo.service" ];

    serviceConfig = {
      ExecStart = forgejoMcpDaemon;
      LoadCredential = [ "forgejo_token:${forgejoMcpTokenFile}" ];
      Restart = "on-failure";
      RestartSec = "10s";
      User = "forgejo";
      Group = "forgejo";
    };
  };
  systemd.services.lean-lsp-mcp = {
    description = "Shared Lean LSP MCP server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    unitConfig.ConditionPathExists = leanMcpBin;

    environment = {
      HOME = "/home/jrestivo";
      PATH = lib.mkForce leanMcpPath;
      UV_CACHE_DIR = "/tmp/uv-cache";
      LEAN_LSP_MCP_ALLOW_PROJECT_SWITCHING = "true";
    };

    serviceConfig = {
      User = "jrestivo";
      Group = "users";
      WorkingDirectory = "/home/jrestivo/dev/lean-lsp-mcp";
      ExecStart = "${leanMcpBin} --transport streamable-http --host 127.0.0.1 --port ${toString leanMcpPort}";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
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

  security.sudo-rs.extraRules = [
    {
      users = [ "gitea-runner" ];
      commands = [
        {
          command = "${forgejoNixosTestSwitch}/bin/forgejo-nixos-test-switch";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

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
        # Fork Actions receive no repository token. Let them clone public PR
        # heads anonymously; private repositories still require authentication.
        REQUIRE_SIGNIN_VIEW = false;
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
        "jrestivo-workstation-local:host"
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
        level = "warn";
        job_level = "warn";
      };
      settings.runner.capacity = forgejoRunnerCapacity;
      settings.container = {
        docker_host = "-";
        force_pull = false;
        force_rebuild = false;
        options = forgejoDockerJobOptions;
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
        level = "warn";
        job_level = "warn";
      };
      settings.runner.capacity = forgejoRunnerCapacity;
      settings.container = {
        docker_host = "unix:///run/docker.sock";
        force_pull = false;
        force_rebuild = false;
        network = "host";
        options = forgejoDockerJobOptions;
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
    environment = {
      HOME = lib.mkForce "/var/cache/forgejo-actions/runner";
      NIX_CONFIG = forgejoRunnerNixConfig;
    };
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "gitea-runner";
      Group = "gitea-runner";
      CPUQuota = forgejoRunnerCpuQuota;
      AllowedCPUs = forgejoRunnerAllowedCPUs;
      MemoryAccounting = true;
      MemoryHigh = forgejoRunnerMemoryHigh;
      MemoryMax = forgejoRunnerMemoryMax;
      WorkingDirectory = lib.mkForce "/var/lib/gitea-runner/desktop";
      ReadWritePaths = [
        "/var/cache/forgejo-actions"
        "/var/tmp"
      ];
    };
  };
  systemd.services."gitea-runner-desktop\\x2ddocker" = {
    environment = {
      HOME = lib.mkForce "/var/cache/forgejo-actions/runner";
      NIX_CONFIG = forgejoRunnerNixConfig;
    };
    after = [ "docker-volume-psi-code-nix.service" ];
    requires = [ "docker-volume-psi-code-nix.service" ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "gitea-runner";
      Group = "gitea-runner";
      CPUQuota = forgejoRunnerCpuQuota;
      AllowedCPUs = forgejoRunnerAllowedCPUs;
      MemoryAccounting = true;
      MemoryHigh = forgejoRunnerMemoryHigh;
      MemoryMax = forgejoRunnerMemoryMax;
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
  systemd.services.forgejo-actions-cache-prune = {
    description = "Prune old Forgejo Actions CI caches";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = forgejoActionsCachePrune;
    };
  };

  systemd.timers.forgejo-actions-cache-prune = {
    description = "Daily prune of old Forgejo Actions CI caches";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
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
    "d /var/cache/forgejo-actions/ironmain/cargo-crap-target 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/frontend-cargo-target 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/isa-metadata-cargo-target 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/lake 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/next 0775 gitea-runner gitea-runner -"
    "d /var/cache/forgejo-actions/ironmain/tmp 0775 gitea-runner gitea-runner -"
    "d /var/tmp/ironmain-ci-work 0775 gitea-runner gitea-runner -"
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
    listenBrainzEndpoint = {
      enable = true;
      token = "local-multi-scrobbler-listenbrainz";
    };
  };

  services.openstreetmap = {
    enable = false;
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
    pi-coding-agent
    pi-subagents
    pi-codex-goal
    context-mode
    hermes-agent
    forgejoNixosTestSwitch
    inputs.psi-coding-agent.packages.${system}.default
    forgejo-mcp
    plane-mcp-server
    repowise
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

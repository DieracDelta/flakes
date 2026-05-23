{ config, pkgs, lib, ... }:
let
  cfg = config.custom_modules.plane;

  # Build frontend with the configured base paths baked in
  planeFrontend = pkgs.plane-frontend.overrideAttrs (old: {
    # Cache buster: ensures rebuild when base derivation buildPhase changes
    name = "plane-frontend-0-unstable-2026-04-28-v5";
    env = (old.env or { }) // {
      VITE_API_BASE_URL = cfg.basePath;
      VITE_WEB_BASE_URL = cfg.basePath;
      VITE_WEB_BASE_PATH = cfg.basePath;
      VITE_ADMIN_BASE_URL = cfg.basePath;
      VITE_ADMIN_BASE_PATH = "${cfg.basePath}/god-mode";
      VITE_SPACE_BASE_URL = cfg.basePath;
      VITE_SPACE_BASE_PATH = "${cfg.basePath}/spaces";
      VITE_LIVE_BASE_URL = cfg.basePath;
      VITE_LIVE_BASE_PATH = "${cfg.basePath}/live";
    };
  });

  planeApi = pkgs.plane-api;
in
{
  options.custom_modules.plane = {
    enable = lib.mkOption {
      description = "Enable Plane project management.";
      type = lib.types.bool;
      default = false;
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain name for Plane (used in Caddy virtualHost and WEB_URL).";
      example = "plane.example.com";
    };

    basePath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Base path to serve Plane under (e.g. '/plane'). Empty for root.";
      example = "/plane";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for the Plane API server.";
    };

    gunicornWorkers = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of gunicorn workers for the API server.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/plane";
      description = "State directory for Plane data, secrets, and storage.";
    };

    database = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "/run/postgresql";
        description = "PostgreSQL host (use socket path for local).";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "plane";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "plane";
      };
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create the PostgreSQL database locally.";
      };
    };

    redis = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 6389;
        description = "Port for the Plane Redis instance.";
      };
    };

    mcp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run a shared Plane MCP HTTP server.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8211;
        description = "Port for the shared Plane MCP HTTP server.";
      };
      workspaceSlug = lib.mkOption {
        type = lib.types.str;
        default = "iro";
        description = "Default Plane workspace slug for local MCP clients.";
      };
      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/home/jrestivo/PLANE_TOKEN";
        description = "Plane API token file read at service startup.";
      };
    };

    rabbitmq = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5672;
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "plane";
      };
      vhost = lib.mkOption {
        type = lib.types.str;
        default = "plane";
      };
    };

    storage = {
      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:9000";
        description = "S3-compatible endpoint URL.";
      };
      bucketName = lib.mkOption {
        type = lib.types.str;
        default = "uploads";
      };
      region = lib.mkOption {
        type = lib.types.str;
        default = "us-east-1";
      };
      versitygw = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Run versitygw with posix backend as the S3 gateway.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 9000;
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # ── User / group ──────────────────────────────────────────────
    users.users.plane = {
      isSystemUser = true;
      group = "plane";
      home = cfg.stateDir;
      createHome = true;
    };
    users.groups.plane = { };

    # ── State directories ─────────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 plane plane -"
      "d ${cfg.stateDir}/logs 0750 plane plane -"
      "d ${cfg.stateDir}/static 0750 plane plane -"
      "d ${cfg.stateDir}/secrets 0750 plane plane -"
      "d ${cfg.stateDir}/storage 0750 plane plane -"
      "d ${cfg.stateDir}/storage/${cfg.storage.bucketName} 0750 plane plane -"
      "d ${cfg.stateDir}/storage 0750 plane plane -"
    ];

    # ── PostgreSQL ────────────────────────────────────────────────
    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    # ── Redis ─────────────────────────────────────────────────────
    services.redis.servers.plane = {
      enable = true;
      port = cfg.redis.port;
      bind = "127.0.0.1";
    };

    # ── RabbitMQ ──────────────────────────────────────────────────
    services.rabbitmq = {
      enable = true;
      listenAddress = "127.0.0.1";
    };

    # ── All systemd services ─────────────────────────────────────
    systemd.services =
      let
        commonEnv = {
          DJANGO_SETTINGS_MODULE = "plane.settings.production";
          DATABASE_URL = if lib.hasPrefix "/" cfg.database.host
            then "postgresql://${cfg.database.user}@/${cfg.database.name}?host=${cfg.database.host}"
            else "postgresql://${cfg.database.user}@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}";
          REDIS_URL = "redis://127.0.0.1:${toString cfg.redis.port}/";
          AMQP_URL = "redis://127.0.0.1:${toString cfg.redis.port}/1";
          RABBITMQ_HOST = cfg.rabbitmq.host;
          RABBITMQ_PORT = toString cfg.rabbitmq.port;
          RABBITMQ_USER = cfg.rabbitmq.user;
          RABBITMQ_VHOST = cfg.rabbitmq.vhost;
          WEB_URL = "https://${cfg.domain}${cfg.basePath}";
          CORS_ALLOWED_ORIGINS = "https://${cfg.domain}";
          USE_MINIO = "0";
          AWS_S3_ENDPOINT_URL = "https://${cfg.domain}";
          AWS_S3_BUCKET_NAME = cfg.storage.bucketName;
          AWS_REGION = cfg.storage.region;
          GUNICORN_WORKERS = toString cfg.gunicornWorkers;
          ADMIN_BASE_PATH = "/god-mode/";
          SPACE_BASE_PATH = "/spaces/";
          LIVE_BASE_PATH = "/live/";
          STATIC_ROOT = "${cfg.stateDir}/static";
          LOG_DIR = "${cfg.stateDir}/logs";
          API_KEY_RATE_LIMIT = "10000000/minute";
          PLANE_BASE_PATH = cfg.basePath;
        };
        commonServiceConfig = {
          User = "plane";
          Group = "plane";
          WorkingDirectory = "${planeApi}/share/plane-api";
          EnvironmentFile = [
            "${cfg.stateDir}/secrets/plane.env"
            "${cfg.stateDir}/secrets/s3.env"
          ];
        };
        apiDeps =
          [ "plane-migrator.service" "redis-plane.service" ]
          ++ lib.optionals cfg.database.createLocally [ "postgresql.service" ]
          ++ lib.optionals cfg.storage.versitygw.enable [ "plane-versitygw.service" ];
      in
      {
        # ── Secret generator ──────────────────────────────────────
        plane-secret-generator = {
          description = "Generate Plane secrets";
          wantedBy = [ "multi-user.target" ];
          before = [
            "plane-migrator.service"
            "plane-api.service"
            "plane-worker.service"
            "plane-beat.service"
            "plane-live.service"
          ] ++ lib.optionals cfg.storage.versitygw.enable [ "plane-versitygw.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "root";
          };
          script = ''
            set -euo pipefail
            umask 077

            ENV_FILE="${cfg.stateDir}/secrets/plane.env"
            if [ ! -f "$ENV_FILE" ]; then
              SECRET_KEY=$(${pkgs.openssl}/bin/openssl rand -base64 48)
              LIVE_SECRET=$(${pkgs.openssl}/bin/openssl rand -base64 32)
              cat > "$ENV_FILE" <<EOF
            SECRET_KEY=$SECRET_KEY
            LIVE_SERVER_SECRET_KEY=$LIVE_SECRET
            EOF
              chown plane:plane "$ENV_FILE"
              chmod 600 "$ENV_FILE"
            fi

            S3_CREDS="${cfg.stateDir}/secrets/s3.env"
            if [ ! -f "$S3_CREDS" ]; then
              ACCESS_KEY=$(${pkgs.openssl}/bin/openssl rand -hex 16)
              SECRET_KEY=$(${pkgs.openssl}/bin/openssl rand -base64 32)
              cat > "$S3_CREDS" <<EOF
            AWS_ACCESS_KEY_ID=$ACCESS_KEY
            AWS_SECRET_ACCESS_KEY=$SECRET_KEY
            ROOT_ACCESS_KEY_ID=$ACCESS_KEY
            ROOT_SECRET_ACCESS_KEY=$SECRET_KEY
            EOF
              chown plane:plane "$S3_CREDS"
              chmod 600 "$S3_CREDS"
            fi
          '';
        };

        # ── MinIO (S3 storage) ─────────────────────────────────────
        plane-versitygw = lib.mkIf cfg.storage.versitygw.enable {
          description = "Versity S3 gateway for Plane";
          wantedBy = [ "multi-user.target" ];
          after = [ "plane-secret-generator.service" ];
          requires = [ "plane-secret-generator.service" ];
          serviceConfig = {
            Type = "simple";
            User = "plane";
            Group = "plane";
            EnvironmentFile = [ "${cfg.stateDir}/secrets/s3.env" ];
            ExecStart = lib.concatStringsSep " " [
              "${pkgs.versitygw}/bin/versitygw"
              "--port :${toString cfg.storage.versitygw.port}"
              "--access $ROOT_ACCESS_KEY_ID"
              "--secret $ROOT_SECRET_ACCESS_KEY"
              "--region ${cfg.storage.region}"
              "posix ${cfg.stateDir}/storage"
            ];
            Restart = "on-failure";
            RestartSec = 5;
          };
        };

        # ── Database migrator (oneshot) ───────────────────────────
        plane-migrator = {
          description = "Plane database migrator";
          wantedBy = [ "multi-user.target" ];
          after =
            [ "plane-secret-generator.service" "redis-plane.service" ]
            ++ lib.optionals cfg.database.createLocally [ "postgresql.service" ];
          requires =
            [ "plane-secret-generator.service" ]
            ++ lib.optionals cfg.database.createLocally [ "postgresql.service" ];
          serviceConfig = commonServiceConfig // {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          environment = commonEnv;
          script = ''
            ${planeApi}/bin/plane-manage wait_for_db
            ${planeApi}/bin/plane-manage migrate

            # Register instance if not already done (creates the instance record)
            ${planeApi}/bin/plane-manage register_instance "${config.networking.hostName}-nix" || true

            # Mark setup as complete — NixOS manages configuration declaratively,
            # no need for the web setup wizard
            ${planeApi}/bin/plane-manage shell -c "
            from plane.license.models import Instance
            inst = Instance.objects.first()
            if inst and not inst.is_setup_done:
                inst.is_setup_done = True
                inst.is_signup_screen_visited = True
                inst.save()
                print('Instance setup marked as complete')
            " || true
          '';
        };

        # ── API server ────────────────────────────────────────────
        plane-api = {
          description = "Plane API server";
          wantedBy = [ "multi-user.target" ];
          after = apiDeps;
          requires = [ "plane-migrator.service" ];
          serviceConfig = commonServiceConfig // {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = 5;
          };
          environment = commonEnv;
          preStart = ''
            ${planeApi}/bin/plane-manage configure_instance
            ${planeApi}/bin/plane-manage create_bucket
            ${planeApi}/bin/plane-manage clear_cache
            ${planeApi}/bin/plane-manage collectstatic --noinput
          '';
          script = ''
            exec ${planeApi}/bin/plane-api \
              --bind 127.0.0.1:${toString cfg.port} \
              --workers ${toString cfg.gunicornWorkers} \
              --max-requests 1200 \
              --max-requests-jitter 1000 \
              --access-logfile -
          '';
        };

        # ── Shared MCP server ────────────────────────────────────
        plane-mcp = lib.mkIf cfg.mcp.enable {
          description = "Plane MCP HTTP server";
          wantedBy = [ "multi-user.target" ];
          after = [ "plane-api.service" ];
          requires = [ "plane-api.service" ];
          serviceConfig = {
            Type = "simple";
            User = "plane";
            Group = "plane";
            Restart = "on-failure";
            RestartSec = 30;
            WorkingDirectory = cfg.stateDir;
            LoadCredential = [ "plane_api_key:${cfg.mcp.tokenFile}" ];
          };
          environment = {
            PLANE_BASE_URL = "http://127.0.0.1:${toString cfg.port}";
            PLANE_INTERNAL_BASE_URL = "http://127.0.0.1:${toString cfg.port}";
            PLANE_WORKSPACE_SLUG = cfg.mcp.workspaceSlug;
            PLANE_OAUTH_PROVIDER_BASE_URL = "http://127.0.0.1:${toString cfg.mcp.port}";
            # The upstream HTTP entrypoint always constructs OAuth and SSE apps
            # before mounting the API-key app that Codex uses. Dummy OAuth
            # credentials satisfy that constructor without enabling OAuth use.
            PLANE_OAUTH_PROVIDER_CLIENT_ID = "local-api-key-mode";
            PLANE_OAUTH_PROVIDER_CLIENT_SECRET = "local-api-key-mode";
          };
          script = ''
            set -euo pipefail
            export PLANE_API_KEY="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/plane_api_key")"
            exec ${pkgs.plane-mcp-server}/bin/plane-mcp-server http
          '';
        };

        # ── Celery worker ─────────────────────────────────────────
        plane-worker = {
          description = "Plane Celery worker";
          wantedBy = [ "multi-user.target" ];
          after = apiDeps;
          requires = [ "plane-migrator.service" ];
          serviceConfig = commonServiceConfig // {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = 5;
            ExecStart = "${planeApi}/bin/plane-worker";
          };
          environment = commonEnv;
        };

        # ── Celery beat ───────────────────────────────────────────
        plane-beat = {
          description = "Plane Celery beat scheduler";
          wantedBy = [ "multi-user.target" ];
          after = apiDeps;
          requires = [ "plane-migrator.service" ];
          serviceConfig = commonServiceConfig // {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = 5;
            ExecStart = "${planeApi}/bin/plane-beat";
          };
          environment = commonEnv;
        };

        # ── Space SSR server ──────────────────────────────────────
        plane-space = {
          description = "Plane Space SSR server";
          wantedBy = [ "multi-user.target" ];
          after = [ "plane-api.service" ];
          serviceConfig = {
            Type = "simple";
            User = "plane";
            Group = "plane";
            ExecStart = "${planeFrontend}/bin/plane-space";
            Restart = "on-failure";
            RestartSec = 5;
          };
          environment = {
            PORT = "3002";
            NODE_ENV = "production";
          };
        };

        # ── Live collaboration server ─────────────────────────────
        plane-live = {
          description = "Plane Live collaboration server";
          wantedBy = [ "multi-user.target" ];
          after = [ "plane-api.service" "redis-plane.service" ];
          serviceConfig = {
            Type = "simple";
            User = "plane";
            Group = "plane";
            EnvironmentFile = [ "${cfg.stateDir}/secrets/plane.env" ];
            ExecStart = "${planeFrontend}/bin/plane-live";
            Restart = "on-failure";
            RestartSec = 5;
          };
          environment = {
            PORT = "3005";
            REDIS_URL = "redis://127.0.0.1:${toString cfg.redis.port}/";
            API_BASE_URL = "http://127.0.0.1:${toString cfg.port}";
            NODE_ENV = "production";
          };
        };
      };

    # ── Caddy reverse proxy ───────────────────────────────────────
    services.caddy.virtualHosts."${cfg.domain}".extraConfig = lib.mkBefore (let
      bp = cfg.basePath;
    in ''
      # S3 uploads — presigned URLs signed against this domain, proxy to versitygw.
      # Caddy preserves the original Host header by default, which matches the signature.
      handle /${cfg.storage.bucketName} {
        reverse_proxy ${cfg.storage.endpoint}
      }
      handle /${cfg.storage.bucketName}/* {
        reverse_proxy ${cfg.storage.endpoint}
      }

      # Strip basePath prefix so backends receive clean paths
      redir ${bp} ${bp}/ permanent
      handle_path ${bp}/* {

        # Space (SSR)
        redir /spaces /spaces/ permanent
        handle /spaces/* {
          reverse_proxy 127.0.0.1:3002
        }

        # Admin (static files)
        redir /god-mode /god-mode/ permanent
        handle_path /god-mode/* {
          root * ${planeFrontend}/share/plane/admin
          try_files {path} {path}/ /index.html
          file_server
        }

        # Live (WebSocket collaboration)
        handle /live/* {
          reverse_proxy 127.0.0.1:3005
        }

        # API
        handle /api/* {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }
        handle /auth/* {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }

        # Static files (Django collectstatic)
        handle /static/* {
          root * ${cfg.stateDir}
          file_server
        }

        # S3 uploads
        handle /${cfg.storage.bucketName}/* {
          reverse_proxy ${cfg.storage.endpoint}
        }

        # Web app (must be last)
        handle /* {
          root * ${planeFrontend}/share/plane/web
          try_files {path} {path}/ /index.html
          file_server
        }
      }
    '');
  };
}

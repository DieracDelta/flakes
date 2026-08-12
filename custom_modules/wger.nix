# wger Workout Manager NixOS module
# Provides PostgreSQL, Redis, Gunicorn, and Celery services
#
# API Access (for Claude/automation):
#   Token: 77a090ae8458cca531c8e8faa05e2bfd50f7669f
#   Usage: curl -H "Authorization: Token <token>" https://office-desktop.tail5ca7.ts.net/wger/api/v2/...
#
# Admin User Setup:
#   To create an admin user declaratively, set adminPasswordFile to a file
#   containing the password. Create the file before rebuilding:
#
#     sudo mkdir -p /var/lib/wger
#     echo "your-secure-password" | sudo tee /var/lib/wger/admin-password
#     sudo chown wger:wger /var/lib/wger/admin-password
#     sudo chmod 600 /var/lib/wger/admin-password
#
#   Then configure:
#     custom_modules.wger = {
#       adminUser = "admin";
#       adminEmail = "your@email.com";
#       adminPasswordFile = "/var/lib/wger/admin-password";
#     };
#
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.wger;
  port = 8002;
  stateDir = "/var/lib/wger";
  mediaDir = "${stateDir}/media";
  staticDir = "${stateDir}/static";

  # Python environment with wger
  pythonEnv = pkgs.python312.withPackages (
    _:
    [
      pkgs.wger
    ]
    ++ pkgs.wger.propagatedBuildInputs
  );

  # Settings directory that will be added to PYTHONPATH
  settingsDir = pkgs.writeTextDir "wger_settings.py" ''
    # wger NixOS deployment settings
    import os
    from settings.settings_global import *

    # Security settings
    DEBUG = False
    ALLOWED_HOSTS = ${builtins.toJSON cfg.allowedHosts}
    CSRF_TRUSTED_ORIGINS = ${builtins.toJSON cfg.trustedOrigins}

    # Database - PostgreSQL
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': 'wger',
            'USER': 'wger',
            'HOST': '/run/postgresql',
            'PORT': ${"''"},
        }
    }

    # Cache - Redis
    CACHES = {
        'default': {
            'BACKEND': 'django_redis.cache.RedisCache',
            'LOCATION': 'unix://${config.services.redis.servers.wger.unixSocket}',
            'TIMEOUT': 7 * 24 * 60 * 60,  # 1 week
            'OPTIONS': {
                'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            }
        }
    }

    # Celery - Redis broker
    CELERY_BROKER_URL = 'redis+socket://${config.services.redis.servers.wger.unixSocket}'
    CELERY_RESULT_BACKEND = 'redis+socket://${config.services.redis.servers.wger.unixSocket}'

    # Static and media files
    STATIC_ROOT = '${staticDir}'
    STATIC_URL = '/wger/static/'
    MEDIA_ROOT = '${mediaDir}'
    MEDIA_URL = '/wger/media/'

    # Site configuration
    SITE_URL = '${cfg.siteUrl}'

    # Subpath configuration - Django needs to know it's served under /wger
    FORCE_SCRIPT_NAME = '/wger'
    LOGIN_URL = '/wger/user/login'
    LOGIN_REDIRECT_URL = '/wger/en/dashboard'
    LOGOUT_REDIRECT_URL = '/wger/'

    # Fix STATICFILES_DIRS to find node_modules in site-packages
    import wger
    _wger_path = os.path.dirname(wger.__file__)
    _node_modules = os.path.join(os.path.dirname(_wger_path), 'node_modules')
    STATICFILES_DIRS = [('node', _node_modules)]

    # Email (use console backend for now)
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

    # Disable axes lockout for now (needs redis or memcached)
    AXES_ENABLED = False

    # ReCaptcha (disabled)
    SILENCED_SYSTEM_CHECKS = ['django_recaptcha.recaptcha_test_key_error']

    # Logging
    LOGGING = {
        'version': 1,
        'disable_existing_loggers': False,
        'handlers': {
            'console': {
                'class': 'logging.StreamHandler',
            },
        },
        'root': {
            'handlers': ['console'],
            'level': 'INFO',
        },
    }

    # Load secret key from file
    with open('${stateDir}/secret_key') as f:
        SECRET_KEY = f.read().strip()
  '';

  # PYTHONPATH needs both settings dir and wger package
  pythonPath = "${settingsDir}:${pythonEnv}/${pkgs.python312.sitePackages}";

  # Wrapper script for Django management
  wgerManage = pkgs.writeShellScriptBin "wger-manage" ''
    export DJANGO_SETTINGS_MODULE=wger_settings
    export PYTHONPATH="${pythonPath}"
    exec ${pythonEnv}/bin/python -m django "$@"
  '';
in
{
  options.custom_modules.wger = {
    enable = mkOption {
      description = "Enable wger Workout Manager.";
      type = types.bool;
      default = false;
    };

    allowedHosts = mkOption {
      description = "Django ALLOWED_HOSTS list.";
      type = types.listOf types.str;
      default = [
        "localhost"
        "127.0.0.1"
        "office-desktop.tail5ca7.ts.net"
      ];
    };

    trustedOrigins = mkOption {
      description = "Django CSRF_TRUSTED_ORIGINS list.";
      type = types.listOf types.str;
      default = [ "https://office-desktop.tail5ca7.ts.net" ];
    };

    siteUrl = mkOption {
      description = "Public URL of the wger instance.";
      type = types.str;
      default = "https://office-desktop.tail5ca7.ts.net/wger";
    };

    adminUser = mkOption {
      description = "Admin username for wger.";
      type = types.str;
      default = "admin";
    };

    adminEmail = mkOption {
      description = "Admin email for wger.";
      type = types.str;
      default = "admin@localhost";
    };

    adminPasswordFile = mkOption {
      description = "Path to file containing admin password.";
      type = types.nullOr types.path;
      default = null;
    };
  };

  config = mkIf cfg.enable {
    # PostgreSQL database
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "wger" ];
      ensureUsers = [
        {
          name = "wger";
          ensureDBOwnership = true;
        }
      ];
    };

    # Redis for cache and Celery
    services.redis.servers.wger = {
      enable = true;
      user = "wger";
      unixSocket = "/run/redis-wger/redis.sock";
      unixSocketPerm = 770;
    };

    # Create wger system user and group
    users.users.wger = {
      isSystemUser = true;
      group = "wger";
      home = stateDir;
      description = "wger service user";
    };
    users.groups.wger = {
      members = [ "caddy" ]; # Allow Caddy to serve static/media files
    };

    # Ensure state directories exist
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 wger wger -"
      "d ${mediaDir} 0750 wger wger -"
      "d ${staticDir} 0755 wger wger -"
    ];

    # Setup service - runs migrations and collects static files
    systemd.services.wger-setup = {
      description = "wger Setup (migrations, collectstatic)";
      after = [
        "postgresql.service"
        "redis-wger.service"
      ];
      requires = [
        "postgresql.service"
        "redis-wger.service"
      ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        DJANGO_SETTINGS_MODULE = "wger_settings";
        PYTHONPATH = pythonPath;
      };

      path = [
        pythonEnv
        pkgs.openssl
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "wger";
        Group = "wger";
        WorkingDirectory = stateDir;
        RemainAfterExit = true;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          stateDir
          "/run/redis-wger"
        ];
      };

      script = ''
        # Generate secret key if not exists
        if [ ! -f ${stateDir}/secret_key ]; then
          openssl rand -base64 50 > ${stateDir}/secret_key
          chmod 600 ${stateDir}/secret_key
        fi

        # Run Django migrations
        ${pythonEnv}/bin/python -m django migrate --noinput

        # Collect static files
        ${pythonEnv}/bin/python -m django collectstatic --noinput --clear

        # Load initial fixtures if database is empty
        if ! ${pythonEnv}/bin/python -m django shell -c "from wger.core.models import Language; exit(0 if Language.objects.exists() else 1)" 2>/dev/null; then
          echo "Loading initial fixtures..."
          ${pythonEnv}/bin/python -m django loaddata languages
          ${pythonEnv}/bin/python -m django loaddata groups
          ${pythonEnv}/bin/python -m django loaddata gym_config
          ${pythonEnv}/bin/python -m django loaddata equipment
          ${pythonEnv}/bin/python -m django loaddata muscles
          ${pythonEnv}/bin/python -m django loaddata licenses
          ${pythonEnv}/bin/python -m django loaddata setting_weight_units
          ${pythonEnv}/bin/python -m django loaddata setting_repetition_units
          ${pythonEnv}/bin/python -m django loaddata categories
          echo "Fixtures loaded."
        fi

        # Create admin user if configured and doesn't exist
        ${lib.optionalString (cfg.adminPasswordFile != null) ''
                    if [ -f "${cfg.adminPasswordFile}" ]; then
                      ADMIN_PASS=$(cat "${cfg.adminPasswordFile}")
                      ${pythonEnv}/bin/python -m django shell -c "
          from django.contrib.auth import get_user_model
          User = get_user_model()
          if not User.objects.filter(username='${cfg.adminUser}').exists():
              User.objects.create_superuser('${cfg.adminUser}', '${cfg.adminEmail}', '$ADMIN_PASS')
              print('Admin user created.')
          else:
              print('Admin user already exists.')
          "
                    else
                      echo "Warning: adminPasswordFile not found at ${cfg.adminPasswordFile}"
                    fi
        ''}
      '';
    };

    # Gunicorn WSGI server
    systemd.services.wger = {
      description = "wger Workout Manager";
      after = [ "wger-setup.service" ];
      requires = [ "wger-setup.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        DJANGO_SETTINGS_MODULE = "wger_settings";
        PYTHONPATH = pythonPath;
      };

      serviceConfig = {
        Type = "simple";
        User = "wger";
        Group = "wger";
        WorkingDirectory = stateDir;
        ExecStart = ''
          ${pythonEnv}/bin/gunicorn wger.wsgi:application \
            --bind 127.0.0.1:${toString port} \
            --workers 4 \
            --timeout 120 \
            --access-logfile - \
            --error-logfile -
        '';
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          stateDir
          "/run/redis-wger"
        ];
      };
    };

    # Celery worker for background tasks
    systemd.services.wger-celery-worker = {
      description = "wger Celery Worker";
      after = [
        "wger-setup.service"
        "redis-wger.service"
      ];
      requires = [
        "wger-setup.service"
        "redis-wger.service"
      ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        DJANGO_SETTINGS_MODULE = "wger_settings";
        PYTHONPATH = pythonPath;
      };

      serviceConfig = {
        Type = "simple";
        User = "wger";
        Group = "wger";
        WorkingDirectory = stateDir;
        ExecStart = ''
          ${pythonEnv}/bin/celery -A wger worker \
            --loglevel=info \
            --concurrency=2
        '';
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          stateDir
          "/run/redis-wger"
        ];
      };
    };

    # Celery beat for scheduled tasks
    systemd.services.wger-celery-beat = {
      description = "wger Celery Beat Scheduler";
      after = [
        "wger-setup.service"
        "redis-wger.service"
      ];
      requires = [
        "wger-setup.service"
        "redis-wger.service"
      ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        DJANGO_SETTINGS_MODULE = "wger_settings";
        PYTHONPATH = pythonPath;
      };

      serviceConfig = {
        Type = "simple";
        User = "wger";
        Group = "wger";
        WorkingDirectory = stateDir;
        ExecStart = ''
          ${pythonEnv}/bin/celery -A wger beat \
            --loglevel=info \
            --schedule=${stateDir}/celerybeat-schedule
        '';
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          stateDir
          "/run/redis-wger"
        ];
      };
    };

    # Caddy reverse proxy at /wger
    services.caddy.virtualHosts."office-desktop.tail5ca7.ts.net".extraConfig = mkAfter ''

      handle_path /wger/static/* {
        root * ${staticDir}
        file_server
      }

      # Some CSS has hardcoded /static/ paths, redirect to /wger/static/
      handle_path /static/* {
        redir * /wger/static{uri} permanent
      }

      handle_path /wger/media/* {
        root * ${mediaDir}
        file_server
      }

      handle_path /wger/* {
        reverse_proxy 127.0.0.1:${toString port}
      }

      redir /wger /wger/ permanent
    '';

    # Homepage dashboard entry
    services.homepage-dashboard.services = mkAfter [
      {
        "Health & Fitness" = [
          {
            "wger" = {
              icon = "mdi-dumbbell";
              href = "/wger/";
              description = "Workout & Nutrition Tracker";
            };
          }
        ];
      }
    ];

    # CLI management tool
    environment.systemPackages = [ wgerManage ];
  };
}

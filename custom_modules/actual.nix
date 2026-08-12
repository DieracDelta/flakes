{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.actual;
  port = 5006;
  # Generate hash with: caddy hash-password
  # Store in /var/lib/caddy/actual-auth containing:
  # basic_auth {
  #     username $2a$14$hashedpassword
  # }
  authFile = "/var/lib/caddy/actual-auth";

  # Bank sync script using locally-built Actual API (from same fork as server)
  # MUST use nodejs_22 to match the version used to build better-sqlite3 in the overlay
  bankSyncScript = pkgs.writeShellApplication {
    name = "actual-bank-sync";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      SYNC_DIR="/var/lib/actual-bank-sync"
      mkdir -p "$SYNC_DIR/data"
      cd "$SYNC_DIR"

      echo "Starting bank sync..."
      # Use locally-built API from the same fork as the server
      NODE_PATH="${pkgs.actual-api}/lib/node_modules" node - <<'SCRIPT'
      const api = require('@actual-app/api');

      async function sync() {
        console.log('Initializing Actual API...');
        await api.init({
          dataDir: '/var/lib/actual-bank-sync/data',
          serverURL: 'http://127.0.0.1:${toString port}/actual',
          password: 'bruh',
        });

        console.log('Fetching budget list...');
        const budgets = await api.getBudgets();

        if (budgets.length === 0) {
          console.log('No budgets found');
          await api.shutdown();
          return;
        }

        for (const budget of budgets) {
          console.log('Syncing budget:', budget.name, 'groupId:', budget.groupId);
          await api.downloadBudget(budget.groupId);
          console.log('Running bank sync...');
          await api.runBankSync();
        }

        await api.shutdown();
        console.log('Bank sync completed successfully');
      }

      sync().catch(e => {
        console.error('Bank sync failed:', e);
        process.exit(1);
      });
      SCRIPT
    '';
  };
in
{
  options.custom_modules.actual.enable = mkOption {
    description = "Enable Actual Budget personal finance manager.";
    type = with types; bool;
    default = false;
  };

  config = mkIf cfg.enable {
    services.actual = {
      enable = true;
      openFirewall = true;
      settings = {
        hostname = "0.0.0.0";
        port = port;
      };
    };

    # Set base path for subpath deployment
    systemd.services.actual.environment.ACTUAL_BASE_PATH = "/actual";

    # Daily bank sync service
    systemd.services.actual-bank-sync = {
      description = "Actual Budget Bank Sync";
      after = [
        "actual.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${bankSyncScript}/bin/actual-bank-sync";
        StateDirectory = "actual-bank-sync";
        # Run as root to access state directory (could be improved with dedicated user)
        User = "root";
      };
    };

    # Daily timer for bank sync
    systemd.timers.actual-bank-sync = {
      description = "Daily Actual Budget Bank Sync";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily"; # Runs at midnight
        RandomizedDelaySec = "1h"; # Random delay up to 1 hour to avoid exact midnight
        Persistent = true; # Run immediately if missed (e.g., system was off)
      };
    };

    # Caddy reverse proxy at /actual/ subpath
    # Using 'handle' (not handle_path) because Actual server handles the /actual prefix itself
    services.caddy.virtualHosts."office-desktop.tail5ca7.ts.net".extraConfig = mkAfter ''

      handle /actual/* {
        # Static assets (anything with a file extension) - no auth needed
        # Workers can't send credentials, so bypass auth for all static files
        @static path_regexp static \.[a-zA-Z0-9]+$
        handle @static {
          reverse_proxy 127.0.0.1:${toString port}
        }
        # Everything else (API endpoints, HTML pages) requires auth
        handle {
          import ${authFile}
          reverse_proxy 127.0.0.1:${toString port}
        }
      }
      redir /actual /actual/ permanent
    '';

    # Homepage dashboard entry
    services.homepage-dashboard.services = mkAfter [
      {
        "Finance" = [
          {
            "Actual Budget" = {
              icon = "actual-budget";
              href = "/actual/";
              description = "Personal Finance & Budgeting";
            };
          }
        ];
      }
    ];
  };
}

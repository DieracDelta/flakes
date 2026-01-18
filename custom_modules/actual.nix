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

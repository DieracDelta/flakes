{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.taskwarrior;
  webPort = 3456;
in
{
  options.custom_modules.taskwarrior = {
    enable = mkOption {
      description = "Enable Taskwarrior with web UI and sync server.";
      type = with types; bool;
      default = false;
    };

    syncServer.enable = mkOption {
      description = "Enable TaskChampion sync server for multi-device sync.";
      type = with types; bool;
      default = true;
    };
  };

  config = mkIf cfg.enable {
    # Install taskwarrior3 CLI
    environment.systemPackages = [
      pkgs.taskwarrior3
      pkgs.taskwarrior-tui
    ];

    # TaskChampion sync server for multi-device sync
    services.taskchampion-sync-server = mkIf cfg.syncServer.enable {
      enable = true;
      port = 10222;
    };

    # Taskwarrior Web UI systemd service
    systemd.services.taskwarrior-web = {
      description = "Taskwarrior Web UI";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        TWK_SERVER_PORT = toString webPort;
        HOME = "/home/jrestivo";
        XDG_CONFIG_HOME = "/home/jrestivo/.config";
      };

      path = [ pkgs.taskwarrior3 ];

      # Initialize taskwarrior database if it doesn't exist
      preStart = ''
        if [ ! -f /home/jrestivo/.task/taskchampion.sqlite3 ]; then
          ${pkgs.taskwarrior3}/bin/task rc.confirmation=off version > /dev/null 2>&1 || true
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = "jrestivo";
        Group = "users";
        WorkingDirectory = "${pkgs.taskwarrior-web}";
        ExecStart = "${pkgs.taskwarrior-web}/bin/taskwarrior-web";
        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [
          "/home/jrestivo/.task"
          "/home/jrestivo/.timewarrior"
          "/home/jrestivo/.config/taskwarrior-web"
          "/home/jrestivo/.cache/taskwarrior-web"
        ];
        PrivateTmp = true;
      };
    };

    # Ensure task data directories exist
    systemd.tmpfiles.rules = [
      "d /home/jrestivo/.task 0750 jrestivo users -"
      "d /home/jrestivo/.timewarrior 0750 jrestivo users -"
      "d /home/jrestivo/.config/taskwarrior-web 0750 jrestivo users -"
      "d /home/jrestivo/.cache/taskwarrior-web 0750 jrestivo users -"
    ];

    # Create taskrc config file for taskwarrior
    home-manager.users.jrestivo.home.file.".taskrc".text = ''
      data.location=~/.task
    '';

    # Caddy reverse proxy at /taskwarrior
    services.caddy.virtualHosts."office-desktop.tail5ca7.ts.net".extraConfig = mkAfter ''

      handle_path /taskwarrior/* {
        reverse_proxy 127.0.0.1:${toString webPort}
      }
      redir /taskwarrior /taskwarrior/ permanent
    '';

  };
}

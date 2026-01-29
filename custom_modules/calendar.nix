# CalDAV Calendar Stack
#
# Lightweight self-hosted calendar with CLI management.
#
# Components:
#   - Radicale: CalDAV server (stores calendar data)
#   - khal: CLI calendar interface
#   - vdirsyncer: Syncs local calendar with Radicale
#
# == SETUP AFTER DEPLOYMENT ==
#
# 1. Create Radicale user (run once):
#      sudo htpasswd -B -c /var/lib/radicale/users jrestivo
#
# 2. Store password for vdirsyncer (same password as above):
#      echo "your-password" > ~/.config/radicale-password
#      chmod 600 ~/.config/radicale-password
#
# 3. Initialize vdirsyncer (creates calendars, run once):
#      vdirsyncer discover
#      vdirsyncer sync
#
# == USAGE ==
#
# Create events:
#   khal new 09:00 10:00 "Meeting with Alice"
#   khal new tomorrow 14:00 15:30 "Code review"
#   khal new 2026-02-01 "All day event"
#
# View calendar:
#   khal list today          # today's events
#   khal list today 7d       # next 7 days
#   khal calendar            # month view
#
# Edit/delete:
#   khal edit "Meeting"      # interactive edit
#
# Sync with server:
#   vdirsyncer sync
#
# == CalDAV ACCESS ==
#
# URL: http://127.0.0.1:5232/ (local)
#      https://office-desktop.tail5ca7.ts.net/caldav/ (via Caddy)
# Protocol: CalDAV (HTTP + iCalendar)
# Auth: HTTP Basic (htpasswd)
#
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.calendar;
  radicalePort = 5232;
in
{
  options.custom_modules.calendar = {
    enable = mkOption {
      description = "Enable CalDAV calendar stack (Radicale server + khal CLI + vdirsyncer).";
      type = with types; bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    # Radicale CalDAV server
    services.radicale = {
      enable = true;
      settings = {
        server = {
          hosts = [ "127.0.0.1:${toString radicalePort}" ];
        };
        auth = {
          type = "htpasswd";
          htpasswd_filename = "/var/lib/radicale/users";
          htpasswd_encryption = "bcrypt";
        };
        storage = {
          filesystem_folder = "/var/lib/radicale/collections";
        };
      };
      rights = {
        # Allow access to root (required for CalDAV discovery)
        root = {
          user = ".+";
          collection = "";
          permissions = "R";
        };
        # Allow users full access to their own collections
        principal = {
          user = ".+";
          collection = "{user}";
          permissions = "RW";
        };
        calendars = {
          user = ".+";
          collection = "{user}/[^/]+";
          permissions = "rw";
        };
      };
    };

    # CLI tools for calendar management
    environment.systemPackages = with pkgs; [
      khal
      vdirsyncer
      apacheHttpd # for htpasswd command
    ];

    # Ensure directories and files exist
    systemd.tmpfiles.rules = [
      # Radicale htpasswd file (user must populate with htpasswd command)
      "f /var/lib/radicale/users 0600 radicale radicale -"
      # Local calendar directories for vdirsyncer/khal
      "d /home/jrestivo/.local/share/calendars 0750 jrestivo users -"
      "d /home/jrestivo/.local/share/vdirsyncer 0750 jrestivo users -"
      "d /home/jrestivo/.local/share/vdirsyncer/status 0750 jrestivo users -"
    ];

    # vdirsyncer configuration for jrestivo
    home-manager.users.jrestivo.xdg.configFile."vdirsyncer/config".text = ''
      [general]
      status_path = "~/.local/share/vdirsyncer/status/"

      [pair calendar]
      a = "calendar_local"
      b = "calendar_remote"
      collections = ["from a", "from b"]
      metadata = ["color", "displayname"]

      [storage calendar_local]
      type = "filesystem"
      path = "~/.local/share/calendars/"
      fileext = ".ics"

      [storage calendar_remote]
      type = "caldav"
      url = "http://127.0.0.1:${toString radicalePort}/"
      username = "jrestivo"
      password.fetch = ["command", "cat", "/home/jrestivo/.config/radicale-password"]
    '';

    # khal configuration for jrestivo
    home-manager.users.jrestivo.xdg.configFile."khal/config".text = ''
      [calendars]

      [[calendar]]
      path = ~/.local/share/calendars/*
      type = discover

      [locale]
      timeformat = %H:%M
      dateformat = %Y-%m-%d
      longdateformat = %Y-%m-%d
      datetimeformat = %Y-%m-%d %H:%M
      longdatetimeformat = %Y-%m-%d %H:%M
      firstweekday = 0

      [default]
      default_calendar = calendar1
      highlight_event_days = True
    '';

    # Caddy reverse proxy for CalDAV
    services.caddy.virtualHosts."office-desktop.tail5ca7.ts.net".extraConfig = mkAfter ''

      redir /caldav /caldav/ permanent

      handle_path /caldav/* {
        reverse_proxy 127.0.0.1:${toString radicalePort} {
          header_up X-Script-Name /caldav
        }
      }

      # CalDAV Calendar Web UI
      redir /calendar /calendar/ permanent

      handle_path /calendar/* {
        root * ${pkgs.caldav-calendar-web}
        file_server
      }
    '';
  };
}

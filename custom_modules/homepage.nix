# Homepage Dashboard configuration
# Service dashboard/landing page
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.homepage;
in
{
  options.custom_modules.homepage.enable = lib.mkOption {
    description = "Enable Homepage dashboard for service overview";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      openFirewall = true;
      listenPort = 8082;
      allowedHosts = "office-desktop.tail5ca7.ts.net";

      services = [
        {
          "Music" = [
            {
              "Navidrome" = {
                icon = "navidrome";
                href = "/navidrome/";
                description = "Music Streamer";
              };
            }
            {
              "Gonic" = {
                icon = "gonic";
                href = "/gonic/";
                description = "Subsonic Music Server";
              };
            }
            {
              "Koito" = {
                icon = "mdi-music-box-multiple";
                href = "/koito/";
                description = "Local Scrobbler";
              };
            }
            {
              "Multi-Scrobbler" = {
                icon = "mdi-music-note-plus";
                href = "/scrobbler/";
                description = "Scrobble Proxy";
              };
            }
            {
              "AudioMuse-AI" = {
                icon = "mdi-music-clef-treble";
                href = "/audiomuse/";
                description = "AI Music Analysis & Playlists";
              };
            }
            # {
            #   "Spotizerr" = {
            #     icon = "box";
            #     href = "/spotizerr/";
            #     description = "Download from Spotify";
            #   };
            # }
          ];
        }
        {
          "AI" = [
            {
              "Open WebUI" = {
                icon = "si-openai";
                href = "https://office-desktop.tail5ca7.ts.net:8444";
                description = "AI Chat Interface";
              };
            }
            {
              "ComfyUI" = {
                icon = "sh-comfyui";
                href = "/comfyui/";
                description = "Stable Diffusion GUI";
                widget = {
                  type = "customapi";
                  url = "http://127.0.0.1:6188/system_stats";
                  refreshInterval = 5000;
                  mappings = [
                    {
                      field = "system.ram_free";
                      label = "Free RAM";
                      format = "bytes";
                    }
                    {
                      field = "devices.0.vram_free";
                      label = "VRAM Free";
                      format = "bytes";
                    }
                  ];
                };
              };
            }
          ];
        }
        {
          "Maps" = [
            {
              "OpenStreetMap" = {
                icon = "mdi-map";
                href = "/osm/";
                description = "Self-hosted Map Tiles";
              };
            }
            {
              "Trip Planner" = {
                icon = "mdi-bus";
                href = "/tripplanner/";
                description = "Digitransit Transit Routing";
              };
            }
            {
              "OTP API" = {
                icon = "mdi-api";
                href = "/otp/";
                description = "OpenTripPlanner API";
              };
            }
          ];
        }
        {
          "Nix" = [
            {
              "Srcbot" = {
                icon = "mdi-file-tree";
                href = "/srcbot/";
                description = "srcbot info";
              };
            }
            {
              "Hydra" = {
                icon = "si-nixos";
                href = "/hydra/";
                description = "CI/CD Build Server";
              };
            }
          ];
        }
        {
          "Projects" = [
            {
              "Lean Docs" = {
                icon = "mdi-book-open-variant";
                href = "/leandocs/";
                description = "Lean Documentation";
              };
            }
            {
              "CTF Dojo" = {
                icon = "mdi-flag";
                href = "https://office-desktop.tail5ca7.ts.net:9444";
                description = "CPSC 4130/5130 CTF Platform";
              };
            }
          ];
        }
        {
          "User Targeted Services" = [
            {
              "SearX" = {
                icon = "searxng";
                href = "/searx/";
                description = "Private Search Engine";
              };
            }
            {
              "Paperless" = {
                icon = "paperless-ngx";
                href = "/paperless/";
                description = "Document Manager";
                widget = {
                  type = "paperlessngx";
                  url = "http://127.0.0.1:28981/paperless";
                  key = "1046ca1ba2c462773d9b630c005f095718f657df";
                };
              };
            }
            {
              "Sunshine" = {
                icon = "sunshine";
                href = "/sunshine/";
                description = "Login: username / password";
              };
            }
          ];
        }
        {
          "System Monitoring Services" = [
            {
              "Netdata" = {
                icon = "netdata";
                href = "/netdata/";
                description = "System Monitoring";
                widget = {
                  type = "netdata";
                  url = "http://127.0.0.1:19999";
                };
              };
            }
            {
              "Glances" = {
                icon = "glances";
                href = "/glances/";
                description = "Real-time Monitor";
                widget = {
                  type = "customapi";
                  url = "http://127.0.0.1:5124/api/4/all";
                  refreshInterval = 3000;
                  mappings = [
                    {
                      field = "cpu.total";
                      label = "CPU";
                      format = "percent";
                    }
                    {
                      field = "mem.percent";
                      label = "RAM";
                      format = "percent";
                    }
                  ];
                };
              };
            }
            {
              "Scrutiny" = {
                icon = "scrutiny";
                href = "/scrutiny/";
                description = "Hard Drive Health";
                widget = {
                  type = "scrutiny";
                  url = "http://127.0.0.1:5123/scrutiny";
                  refreshInterval = 60000;
                };
              };
            }
            {
              "Ntopng" = {
                icon = "ntopng";
                href = "/ntopng/";
                description = "Network Traffic Monitor";
              };
            }
            {
              "UPS Status" = {
                icon = "nut";
                href = "/nut/metrics";
                description = "Power Backup";
              };
            }
            {
              "Grafana" = {
                icon = "grafana";
                href = "/grafana/";
                description = "Dashboards & Analytics";
              };
            }
          ];
        }
        {
          "Productivity" = [
            {
              "Taskwarrior" = {
                icon = "mdi-checkbox-marked-outline";
                href = "/taskwarrior/";
                description = "Task Management";
              };
            }
            {
              "Calendar" = {
                icon = "mdi-calendar";
                href = "/calendar/";
                description = "CalDAV Calendar Web UI";
              };
            }
            {
              "Radicale" = {
                icon = "mdi-calendar-edit";
                href = "/caldav/.web/";
                description = "Manage Calendar Collections";
              };
            }
          ];
        }
        {
          "Infrastructure" = [
            {
              "Tailscale" = {
                icon = "tailscale";
                href = "https://login.tailscale.com/admin/machines";
                description = "VPN Mesh Network";
                widget = {
                  type = "tailscale";
                  key = "tskey-api-kQPWtb565N11CNTRL-wsrbzUVc9cU5Y4dCK4zGkU5pCpacQXAb";
                  deviceid = "nvD4xX4tfM11CNTRL";
                };
              };
            }
            {
              "Caddy" = {
                icon = "caddy";
                href = "/caddy-api/config/";
                description = "Reverse Proxy";
                widget = {
                  type = "caddy";
                  url = "http://127.0.0.1:2019";
                };
              };
            }
            {
              "AdGuard Home" = {
                icon = "adguard-home";
                href = "/adguard/";
                description = "DNS Ad-blocking";
                widget = {
                  type = "adguard";
                  url = "http://127.0.0.1:3003";
                };
              };
            }
            {
              "IP KVM" = {
                icon = "mdi-remote-desktop";
                href = "https://glkvm.tail5ca7.ts.net/#/";
                description = "Remote KVM Access";
              };
            }
          ];
        }
      ];

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
      ];
    };
  };
}

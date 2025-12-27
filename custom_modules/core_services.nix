{
  config,
  pkgs,
  lib,
  options,
  system,
  nixpkgs-stable,
  ...
}:
# TODO read these in from secrets.yaml by parsing yaml file
# TODO fix naming inconsistency
let
  secrets = [
    "zerotier_key"
    "rust_filehost_secrets"
    "rust_filehost_secret_key"
    "email_password"
    "hashed_email_password"
    "gitlab_password"
  ];
  genDefaultPerms = secret: {
    ${secret} = {
      mode = "0440";
      owner = config.users.users.jrestivo.name;
      group = config.users.users.jrestivo.group;
    };
  };
  cfg = config.custom_modules.core_services;
in
{
  options.custom_modules.core_services.enable = lib.mkOption {
    description = ''
      Core services to be enabled on everything. Includes secrets, ssh, zerotier, tailscale, firewall, etc. Also sets up users, ssh keys, internet, nix cache.
    '';
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf cfg.enable {
    # madness.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    networking.nameservers = [
      "100.100.100.100"
      "1.1.1.1"
    ];
    # TODO pass in global root state to create path from
    # sops.defaultSopsFile = ../secrets/secrets.yaml;
    # sops.secrets = (((lib.foldl' lib.mergeAttrs) { }) (builtins.map genDefaultPerms secrets))
    #   // { tailscale_key.owner = "root"; };

    # OP ssh between all the devices
    # services.zerotierone.enable = true;
    # TODO move this to a secret
    # services.zerotierone.joinNetworks = [ "af415e486feddf70" ];

    # even more OP ssh between all the devices
    services.tailscale = {
      enable = true;
    };

    systemd.services.tailscale-optimization = {
      description = "Optimize ethtool settings for Tailscale";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.ethtool} -K enp6s0 rx-udp-gro-forwarding on rx-gro-list off";
      };
    };
    services.caddy = {
      enable = true;

      globalConfig = ''
        https_port 8443
      '';

      virtualHosts."office-desktop.tail5ca7.ts.net" = {
        extraConfig = ''
          bind 127.0.0.1

          redir /navidrome /navidrome/
          handle /navidrome* {
            reverse_proxy 127.0.0.1:4533
          }

          handle_path /netdata* {
            reverse_proxy 127.0.0.1:19999
          }

          redir /glances /glances/
          handle_path /glances* {
            reverse_proxy 127.0.0.1:5124
          }

          handle /scrutiny* {
            reverse_proxy localhost:5123
          }

          handle_path /searx* {
            reverse_proxy 127.0.0.1:3838
          }

          handle /ntopng* {
            reverse_proxy 100.74.54.40:3123
          }

          handle /paperless* {
            reverse_proxy localhost:28981 {
              header_up Remote-User "admin"
            }
          }

          handle_path /nut* {
            reverse_proxy localhost:16180
          }

          handle /grafana* {
            reverse_proxy 127.0.0.1:3000
          }

          handle_path /sunshine* {
            reverse_proxy https://127.0.0.1:48012 {
              transport http {
                tls_insecure_skip_verify
              }
              header_up X-Forwarded-Proto {scheme}
              header_up X-Forwarded-Prefix /sunshine
            }
          }

          handle_path /spotizerr* {
            reverse_proxy 127.0.0.1:7171
          }

          handle_path /comfyui* {
            reverse_proxy 127.0.0.1:6188
          }

          handle_path /caddy-api* {
            reverse_proxy 127.0.0.1:2019 {
              header_up Host {upstream_hostport}
            }
          }

          handle {
            reverse_proxy 127.0.0.1:8082
          }

        '';
      };
    };

    services.caddy.virtualHosts."office-desktop.tail5ca7.ts.net:8444" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:8080
      '';
    };
    services.tailscale.permitCertUid = "caddy";

    services.homepage-dashboard = {
      enable = true;
      openFirewall = true;
      listenPort = 8082; # The internal port (default is 8082 on NixOS)
      allowedHosts = "office-desktop.tail5ca7.ts.net";

      # This defines the layout of your dashboard
      services = [
        {
          "User Targeted Services" = [
            {
              "Open WebUI" = {
                icon = "si-openai";
                href = "https://office-desktop.tail5ca7.ts.net:8444";
                description = "AI Chat Interface";
              };
            }
            {
              "Navidrome" = {
                icon = "navidrome";
                href = "/navidrome/";
                description = "Music Streamer";
              };
            }
            {
              "SearX" = {
                icon = "searxng"; # or "searx"
                href = "/searx/";
                description = "Private Search Engine";
              };
            }
            {
              "Paperless" = {
                icon = "paperless-ngx";
                href = "/paperless/"; # Browser link
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
            {
              "Spotizerr" = {
                icon = "box";
                href = "/spotizerr/";
                description = "Download from spotify";
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
                href = "/glances/"; # Matches the Caddy path
                description = "Real-time Monitor";
                widget = {
                  type = "customapi";
                  url = "http://127.0.0.1:5124/api/4/all";
                  refreshInterval = 3000; # Refresh every 3 seconds

                  # We map the JSON data manually to avoid the parsing bug
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
                  # Optional: Force it to update every 60 seconds
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
                icon = "nut"; # or "battery"
                # Link to the Prometheus Exporter text page (via Caddy)
                href = "/nut/metrics";
                description = "Power Backup";
              };
            }
            {
              "Grafana" = {
                icon = "grafana";
                href = "/grafana/";
                description = "Dashboards & Analytics";
                # would need to fix login thing
                # widget = {
                #   type = "grafana";
                #   url = "http://127.0.0.1:3000/grafana";
                # };
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
                  # Caddy's default admin API port
                  url = "http://127.0.0.1:2019";
                };
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

    # create a oneshot job to authenticate to Tailscale
    # systemd.services.tailscale-autoconnect = {
    # description = "Automatic authentication to Tailscale";

    # # make sure tailscale is running before trying to connect to tailscale
    # after = [ "network-pre.target" "tailscale.service" ];
    # wants = [ "network-pre.target" "tailscale.service" ];
    # wantedBy = [ "multi-user.target" ];

    # # set this service as a oneshot job
    # serviceConfig.Type = "oneshot";

    # # have the job run this shell script
    # script = with pkgs; ''
    # # wait for tailscaled to settle
    # sleep 2

    # # check if we are already authenticated to tailscale
    # status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
    # if [[ "$status" == "Running" ]]; then
    # exit 0
    # fi

    # # otherwise authenticate with tailscale
    # ${tailscale}/bin/tailscale up -authkey "$(cat ${config.sops.secrets.tailscale_key.path})"
    # '';
    # serviceConfig.SupplementaryGroups = [ config.users.groups.keys.name ];
    # };

    services.sslh = {
      enable = true;
      # "listenAddresses" replaces the old "port" setting
      listenAddresses = [ "0.0.0.0" ];

      settings = {
        transparent = false;
        protocols = [
          {
            name = "ssh";
            service = "ssh";
            host = "127.0.0.1";
            port = "22";
          }
          {
            name = "tls";
            host = "127.0.0.1";
            port = "8443";
          }
        ];
      };
    };

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      # I'm adding all these ports because apparently southwest blocks ssh ports after
      # a certain amount of time? So I'll need to switch between them.
      ports = [
        22
        24
        200
        201
        202
        2001
        2002
      ];
      openFirewall = true;
    };
    services.sunshine = {
      package = pkgs.sunshine.override { cudaSupport = true; };

      autoStart = true;
      enable = true;
      capSysAdmin = true;
      openFirewall = true;
      settings.port = 48011;
    };
    systemd.user.services.sunshine.serviceConfig = {
      Nice = -10;
      CPUWeight = 1000;
      IOSchedulingPriority = 0;
      IOWeight = 1000;
    };

    systemd.services.ssdh.serviceConfig = {
      Nice = -10;
      CPUWeight = 1000;
      IOSchedulingPriority = 0;
      IOWeight = 1000;
    };

    systemd.settings.Manager = {
      DefaultIOAccounting = true;
      DefaultIPAccounting = true;
    };

    # systemd.sockets.sshd.socketConfig = {
    #   IPTOS = "low-delay";
    #   Priority = 6;
    # };
    #
    # systemd.sockets.nix-daemon.socketConfig = {
    #   IPTOS = "low-delay";
    #   Priority = 2;
    # };
    # systemd.sockets.sunshine.socketConfig = {
    #   IPTOS = "low-delay";
    #   Priority = 7;
    # };

    programs.ssh = {
      forwardX11 = true;
      setXAuthLocation = true;
    };

    # ollama and webui are 11434 and 8080 respectively
    networking.firewall.allowedTCPPorts = [
      19999
      3838
      3389
      80
      443
      8443
      444
      9993
      8080
      3123
      8188
      11434
      47990
      47989
    ];

    services.lorri.enable = true;

    services.gnome.gnome-keyring.enable = true;

    services.locate = {
      enable = true;
      interval = "weekly";
      pruneNames = [
        ".git"
        "cache"
        ".cache"
        ".cpcache"
        ".aot_cache"
        ".boot"
        "node_modules"
        "USB"
      ];
      prunePaths = options.services.locate.prunePaths.default ++ [
        "/dev"
        "/lost+found"
        "/nix/var"
        "/proc"
        "/run"
        "/sys"
        "/usr/tmp"
      ];
    };

    programs.fish.enable = true;
    programs.zsh.enable = true;
    # users.groups.jellyfinMedia = { };
    users.users = {
      siraben = {
        isNormalUser = true;
        home = "/home/siraben";
        shell = pkgs.zsh;
        extraGroups = [ "wheel" ];
      };

      john = {
        isNormalUser = true;
        home = "/home/john";
        shell = pkgs.zsh;
        extraGroups = [ "wheel" ];
      };

      jachym = {
        isNormalUser = true;
        home = "/home/jachym";
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "networkmanager"
          "audio"
          "input"
          "docker"
          "adbusers"
          "jackaudio"
          "keys"
          "plugdev"
          "video"
          "render"
        ];
      };

      faye = {
        isNormalUser = true;
        home = "/home/faye";
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "networkmanager"
          "audio"
          "input"
          "docker"
          "adbusers"
          "jackaudio"
          "keys"
          "plugdev"
          "video"
          "render"
        ];
      };

      jrestivo = {
        isNormalUser = true;
        home = "/home/jrestivo";
        shell = pkgs.fish;
        description = "Justin --the owner-- Restivo";
        extraGroups = [
          "wheel"
          "networkmanager"
          "audio"
          "input"
          "docker"
          "adbusers"
          "jackaudio"
          "keys"
          "plugdev"
          "video"
          "render"
          "dialout"
          "jellyfin"
          # "jellyfinMedia"
        ];
        initialPassword = "bruh";
      };
    };
    # environment.etc = { };

    networking.useDHCP = false;
    networking.networkmanager.enable = true;

    time.timeZone = "America/New_York";
    location.provider = "geoclue2";

    system.stateVersion = "25.11";

    environment.variables = {
      BROWSER = "chromium";
      EDITOR = "nvim";
    };
    users.users.faye.openssh.authorizedKeys.keys = [
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvl4EJTj/aStbkEr6Mt9VAcjFieB26i6KbYrYvcJvam wyvtt@proton.me
      ''
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFG7ussfetgtlBtZ500gY66cMCs9+ZTko1wqZprMOSWFFZl+EBQ2cOQj2lp8P27x31SqY2DNXlkBZ1yURxAdh9yBdm/Gtg2t/YrTwM8+9QYVUl92r/1Ogw0wV7k1WmHm4rUHMqOL6t4mF+HRdyFKY5hALNNxjI0DXn1OlNBi9wjtohkdDTokkWuMbHnfBH1rHWVN4wFG6Qfi5D4471fP4MXScP40Xmj9HcFi+l7NnelC2JvTLAYfV+jWTrXhe1CV+UGrcqGfShkiMs2rkv4rj41kM2vORFhGhUjksJje/IZeM1gOd5GG/+lcxmsBaxNEUJGj2X8WxBz6ALrlaxjFcVB7WYsywNQihb/V6ZPas2jQ7XyboziVvY2FFptryXUA/z5BkD4HjZRozbZdfhIzzVg+/FqWoc7xOktTKzEtwb1RT7nL33V3koZhqwHubqCObLIHsvr06S1OSprNHoTHwpZYV+bSWn5ufDadsyJ4SSm3XNIpYC946eyehtsFHXmJHmrV1sAMf/U3REWDww1VCWebmgV7o9yF7uoP/ixpLvos5bXD91uzrfMOdmTxE94FAcg5yQm86Rjpt++3sLPnHswEuSZWaDpv5u0PnAReGkgJxjfg9Zm9c5w1CzQWKlRiFnO4UorgcKb3CFAeM9PNNrYSngmjr5dZKYEbxMBJKBOQ== ollamaui@gpe-er14317-04m.concordia.ca
      ''
    ];

    users.users.jachym.openssh.authorizedKeys.keys = [
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDM+Q5ZKAE/OoP7uv5xjCV3DDBJhnAgSqb6VT+ZanrWhIvyBDw5ZDbhat2Urc7shbQxCjKWUN+HJi9sd3aV26SqfKCdE13xzxgMPf3GEAfcJVCIIslIr7vpXsFhE0o2WgGDkzSYc9tviLlVOWCPTMdJm4EZTbEaGI2rlCbwWQFnE7inwTh6RpDRwtONnT8enCfZ5BMPWcDFsRU/7GYxyphFZ7mxJTUoqNH4uXXsX82joPTGSGoDuxkNvkA30BR2kLNAqS31ceEPN02EhT8mzwyqwpg47y0ab7UeRHkyfpXBMH0AQA2pXjz3qRQeobF/P7Tebv2d33LUaCPFfA08Pyvva/cv4fUrRc9iVsdtEh/quCdpORfPxQ6vLNnfsrU72Z1cBQEBA99Nf3Q6R2TRz2eVBNNgHLdX+V8YQ8MwVvlBIFsjJQHN7r954jfwKw4q5hz/NttVZjj95BXMPJpzjQ5vQsR4zeVZUdQTo/L3cXGw17NFZyKD2/IajhT//7BmZcIFOb3sMvywy83RUIiSB0ch1KWbicLUDoCSlGY73uzO6LcC63Vk3/cimsJesaPCyvws6Bv7ILAhDHcFatN3SvN9tOTZgkEKi8Td2uTCJQR11H1gzWs+6wjygi5Pn8vz909V4WOQGtt4TwBP9W+r0gBPfJeuRiCT0Fy4W3EcsdbvOw==
      ''
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiGXTcWHOZal887+8PebZh1sR0SKBxJsRWsm3aXUSHn
      ''
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZbaVIMukjpEXeKDJG3IHl9wO3aFbyHNbucC89RywML jachym.putta@gmail.com
      ''
    ];

    users.users.john.openssh.authorizedKeys.keys = [
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ61iahx0HtGVD0qtBFIr8nTPivNxQimrqaloBazYCPK
      ''
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMsUDBfzag72+L0fHeoFJwp8azXn7CedR77PBunqSqxS
      ''
    ];

    users.users.siraben.openssh.authorizedKeys.keys = [
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDGSUM4kaMhd0SaR7qXXbdUtTRy4uC9cPqbpfJ3QP+zZZfeU/rMg4Gv8w10JmFfvrPWFCRgZ3su7ewN+We3rbmN2qDxArOPdzjBfQ/N33epz1Th3fpswdoLmyYtUxeugqGo9TM2e4K4OwJwJnrOvfbfqqhkwvCYgcHzjsA2I1tEThI6eKcYInhq8IOSmwtnGNvl77HrH6cnXcrX3OK9XVSeHVzJKVwzb0IDsdr2fUdwCQZnlfeVj/LuXlDn5hueLQbi5qzyMdI+KeQA3i2iu+aq35Yn7ubOZjQ0kM0uCcm6nhWp4bXtSFGA4Kj4GwOvpTVULSdIW7mu6f37/OTW9MyuJnsFYxJgDUMB8giH4LHEOI9ZhYpkrvO01Lh2igCCVe8GGqDkpu9OQEzWRnFdE3oFH9QbPSWtniX2ZWH/zkoxP2iVGxJkcOiOZGAEsF19skyaCDyu0ZwC8xGzu8S6ZZic+BHeeXXstiquMuTemlU8dqxtmo+cw2xo7JqSZu20EPKjlXz/V6cVTfPQXeH+ANRz4bihdTfHEIEmAXH9PU4vni63loJvSdGqTITUtmQDpeSu+e5qF48IX+Hu+x+Hr/1HhGVn1o2G1DjutM+9BobHiMAq+rh/tPMc1zGlsdCyXf3121WBOrFG4fD/ZCdJoMAZzKaqmaIrcLvQbEVCrRHXNw==
      ''

    ];

    users.users.jrestivo.openssh.authorizedKeys.keys = [
      #phone
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFJuaewj/iKW2mZP1TAMcUYuMYz5j8TN18V6EafejPNE
      ''
      # vps
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINX0/chTwc1ji+HpxsbY6D0bj9XrgGvIwUKTrwala6jH your_email@example.com
      ''
      #laptop
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5qlN93RBt99GVy6YDP3OMb7Yu4zwELvT5kvdTRnPzE9txmdxKiMM8eHGw4vBwcbmwY7y1wa+ijXwiT0PbwDUOQvVu8CzWHxBF0pz8LVy7XsBuQr9UtxXVV6D9KBKJJEQjpKgF0LTGOC3LSdHKqlH/4zUaUpE2ZPOaoS01S8YwNfRbr30XDeilMDD5rY0AVlydKFRZIbf/96fdo4HURKcjRMapTdYrdkj++FINCl4IDOId3UQR7Z8qDmx2IC6rOikMNMGwEFvgueCDHDuieqNfHn9LVv8gzCPZ0QtX5Ap+6FPNiUfBXuG1IK7RzeDicGUSXWfKFQImwo6pppArqvtqizEFY6WDBSso5XTveg3Z/gH5/jfMigElVAh8xob/NAW2lv6lHEjXtFVmk3N2Fz425SfXQp2qyaYOPGYohWt1ZwlMdkHYfYGtskaoUd9XCM3GC+aSSLkMPuaXtLS3aJ9R7jcz4sfXdU0s3Vd+jQl7c9n3lGYlZ59aKruUj50QtAs= jrestivo@jrestivo.local
      ''
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnVsxxx7yiI1yWh2+wkmH7jMDTfvypsLfVkYuz+WObIi3V+1gZN3cPjHFYwEa1SpUNSs4/c2zdM1CANR5b61YgBmvbxYUVCBFNSeO1B9JTPUDcyM20vhRdeUOFlPS0KJHkKnlzjq4sEnjDM+zXCtAKEekBRcWqcnK2WX/Q9CI6+ocaJ30r06T0Hqa4C7Gx6pNbVNxaTaza3Mzod68aBjyg7WShsKPF5nLSe9QJIjUQ2bjGdRCUlXshgmW+E127KqryZqYLmmodF9fynCK6Ne+MDM2jEruRHMwhv50MfnO0ntOOM0i37oR3JuKE+AzJj/+Ete/YVbbIxipMm0DkNJEEqFsZRO5qkiP2MpI4TCZxHaac/pl+W6HdhwzSKCUrVBUTwEacaz/3WFgGgTjebpW1hfYbcTalG6e9t2W0OSg+INYLklp4uHDWHjFqyl5J+FZMNQdtWgD3yRyZN9rf1ojVf5AgxSW6pXIcrqMf/6Kf+kr/O0FOakrLaEHTDmONVTM= justin.p.restivo@gmail.com
      ''
      # MOST RECENT
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5DtmAk4jcG0i0m1HCnhienAMUgBQ25Srs5P9pRe1eL openpgp:0x1CE431A7
      ''
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpGFCfG6Yq+CaAqNZcU41FhGv5JcLehkUa59eaw35iM openpgp:0x16CE5BD0
      ''
      # jared
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID26MAsR89ZknXksgR5S4x2c9HZy1db/ioFqiXllaGpU jarednathanielrestivo@Laptop-2.local
      ''
    ];
    users.users.root.openssh.authorizedKeys.keys = [
      #laptop
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5qlN93RBt99GVy6YDP3OMb7Yu4zwELvT5kvdTRnPzE9txmdxKiMM8eHGw4vBwcbmwY7y1wa+ijXwiT0PbwDUOQvVu8CzWHxBF0pz8LVy7XsBuQr9UtxXVV6D9KBKJJEQjpKgF0LTGOC3LSdHKqlH/4zUaUpE2ZPOaoS01S8YwNfRbr30XDeilMDD5rY0AVlydKFRZIbf/96fdo4HURKcjRMapTdYrdkj++FINCl4IDOId3UQR7Z8qDmx2IC6rOikMNMGwEFvgueCDHDuieqNfHn9LVv8gzCPZ0QtX5Ap+6FPNiUfBXuG1IK7RzeDicGUSXWfKFQImwo6pppArqvtqizEFY6WDBSso5XTveg3Z/gH5/jfMigElVAh8xob/NAW2lv6lHEjXtFVmk3N2Fz425SfXQp2qyaYOPGYohWt1ZwlMdkHYfYGtskaoUd9XCM3GC+aSSLkMPuaXtLS3aJ9R7jcz4sfXdU0s3Vd+jQl7c9n3lGYlZ59aKruUj50QtAs= jrestivo@jrestivo.local
      ''
      # MOST RECENT
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5DtmAk4jcG0i0m1HCnhienAMUgBQ25Srs5P9pRe1eL openpgp:0x1CE431A7
      ''
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnVsxxx7yiI1yWh2+wkmH7jMDTfvypsLfVkYuz+WObIi3V+1gZN3cPjHFYwEa1SpUNSs4/c2zdM1CANR5b61YgBmvbxYUVCBFNSeO1B9JTPUDcyM20vhRdeUOFlPS0KJHkKnlzjq4sEnjDM+zXCtAKEekBRcWqcnK2WX/Q9CI6+ocaJ30r06T0Hqa4C7Gx6pNbVNxaTaza3Mzod68aBjyg7WShsKPF5nLSe9QJIjUQ2bjGdRCUlXshgmW+E127KqryZqYLmmodF9fynCK6Ne+MDM2jEruRHMwhv50MfnO0ntOOM0i37oR3JuKE+AzJj/+Ete/YVbbIxipMm0DkNJEEqFsZRO5qkiP2MpI4TCZxHaac/pl+W6HdhwzSKCUrVBUTwEacaz/3WFgGgTjebpW1hfYbcTalG6e9t2W0OSg+INYLklp4uHDWHjFqyl5J+FZMNQdtWgD3yRyZN9rf1ojVf5AgxSW6pXIcrqMf/6Kf+kr/O0FOakrLaEHTDmONVTM= justin.p.restivo@gmail.com
      ''
      # MOST RECENT
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpGFCfG6Yq+CaAqNZcU41FhGv5JcLehkUa59eaw35iM openpgp:0x16CE5BD0
      ''

    ];

    nix = {
      # binaryCaches = [
      #   "https://jrestivo.cachix.org"
      # ];
      # binaryCachePublicKeys = [
      #   "jrestivo.cachix.org-1:+jSOsXAAOEjs+DLkybZGQEEIbPG7gsKW1hPwseu03OE="
      # ];

      # warn-dirty = true;
      extraOptions = ''
        gc-keep-outputs = true
        warn-dirty = false
        experimental-features = nix-command flakes pipe-operators auto-allocate-uids cgroups
        extra-platforms = x86_64-linux i686-linux aarch64-linux armv7l-linux
        sandbox-dev-shm-size = 5%
        use-cgroups = true
        auto-allocate-uids = true
        download-buffer-size = 500000000
      '';
      # json-log-path = /tmp/nixbtm.sock
      # riscv64-linux

      # cachix stuffs
      settings.substituters = [
        "https://cache.nixos.org"
        "https://cuda-maintainers.cachix.org"
        "https://cachix.cachix.org"
        # "https://jrestivo.cachix.org"
        "http://nix-community.cachix.org/"
        "https://comfyui.cachix.org"
      ];
      settings.trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      ];
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d --max-freed $((64 * 1024**3))";
      };
      optimise = {
        automatic = true;
        dates = [ "weekly" ];
      };
    };

    # ONLY cli stuff
    environment.systemPackages = with pkgs; [
      dmidecode
      # deploy-rs
      bottom

      direnv
      git
      tigervnc
      evemu
      xdg-utils
      dnsutils
      # NOTE: brocken apparently
      # hwloc
      ngrok
      gnupg
      ssh-to-pgp
      lsof
      nox
      atuin
      nix-du
      nixpkgs-fmt
      #zsh-forgit
      # procs
      eza
      # nix-output-monitor
      nixos-generators
      evtest
      unzip
      nix-tree
      # nixFlakes
      fzf
      # cachix
      bat
      entr
      bat-extras.prettybat
      bat-extras.batgrep
      bat-extras.batdiff
      bat-extras.batman
      bat-extras.batpipe
      bat-extras.batwatch
      bat-extras.core
      manix
      zsh
      ripgrep
      neofetch
      opensnitch-ui
      tmux
      fasd
      jq
      mosh
      pstree
      tree
      nix-index
      file
      fd
      sd
      tealdeer
      ffmpeg
      dnsutils
      mkpasswd
      htop
      wget
      ispell
      whois
      zoom-us
      # uv
      gamescope
      nixpkgs-review
      # (sunshine.override { cudaSupport = true; })
      # sunshine
    ];
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "65536";
      }
      {
        domain = "*";
        type = "hard";
        item = "nofile";
        value = "1048576";
      }
    ];
    programs.gamescope.enable = true;

    programs.mosh.enable = true;
  };
}

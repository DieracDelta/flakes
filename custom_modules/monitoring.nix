{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.custom_modules.monitoring;

  # Import dashboard definitions
  dashboards = {
    ups = import ./dashboards/ups.nix;
    gpu = import ./dashboards/gpu.nix;
    system = import ./dashboards/system.nix;
    systemd = import ./dashboards/systemd.nix;
    network = import ./dashboards/network.nix;
    smart = import ./dashboards/smart.nix;
  };
in
{
  options.custom_modules.monitoring = {
    enable = lib.mkEnableOption "Prometheus/Grafana monitoring stack";
    enableGpu = lib.mkEnableOption "GPU monitoring with DCGM exporter";
    enableUps = lib.mkEnableOption "UPS monitoring with NUT";
  };

  config = lib.mkIf cfg.enable {
    # ===================
    # Prometheus
    # ===================
    services.prometheus = {
      enable = true;
      exporters.node = {
        enable = true;
        enabledCollectors = [
          "cpu"
          "cpufreq"
          "diskstats"
          "filesystem"
          "hwmon"
          "loadavg"
          "meminfo"
          "netdev"
          "pressure"
          "rapl"
          "stat"
          "thermal_zone"
          "vmstat"
          "textfile"
        ];
        extraFlags = [ "--collector.textfile.directory=/var/lib/node_exporter/textfile_collector" ];
        port = 9100;
      };
      exporters.systemd = {
        enable = true;
        port = 9558;
        listenAddress = "0.0.0.0";
        extraFlags = [
          "--systemd.collector.enable-restart-count"
        ];
      };
      exporters.smartctl = {
        enable = true;
        port = 9633;
      };
      scrapeConfigs =
        # Node exporter scrape config (always enabled)
        [
          {
            job_name = "node";
            static_configs = [
              { targets = [ "127.0.0.1:9100" ]; }
            ];
          }
          {
            job_name = "systemd";
            static_configs = [
              { targets = [ "127.0.0.1:9558" ]; }
            ];
          }
          {
            job_name = "smartctl";
            static_configs = [
              { targets = [ "127.0.0.1:9633" ]; }
            ];
          }
        ]
        ++
          # NUT scrape config
          (lib.optionals cfg.enableUps [
            {
              job_name = "nut";
              metrics_path = "/ups_metrics";
              static_configs = [
                { targets = [ "127.0.0.1:16180" ]; }
              ];
            }
          ])
        ++
          # DCGM GPU scrape config
          (lib.optionals cfg.enableGpu [
            {
              job_name = "dcgm";
              static_configs = [
                {
                  targets = [ "127.0.0.1:9400" ];
                  labels.instance = "desktop";
                }
              ];
            }
          ]);
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/node_exporter/textfile_collector 0777 root root -"
    ];

    # Allow smartctl-exporter to access NVMe character devices
    services.udev.extraRules = ''
      SUBSYSTEM=="nvme", KERNEL=="nvme[0-9]*", GROUP="disk", MODE="0660"
    '';
    users.groups.smartctl-exporter-access = { };

    # ===================
    # Grafana
    # ===================
    services.grafana = {
      enable = true;
      settings.server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        root_url = "https://office-desktop.tail5ca7.ts.net/grafana/";
        serve_from_sub_path = true;
      };
      settings.auth = {
        disable_login_form = true;
      };
      settings."auth.anonymous" = {
        enabled = true;
        org_role = "Admin";
        org_name = "Main Org.";
      };

      provision.datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:9090";
            access = "proxy";
            isDefault = true;
          }
        ];
      };

      provision.dashboards.settings = {
        apiVersion = 1;
        providers =
          # System dashboard (always enabled)
          [
            {
              name = "system-dashboard";
              orgId = 1;
              folder = "System";
              type = "file";
              disableDeletion = false;
              editable = true;
              allowUIUpdates = true;
              options.path = "/etc/grafana-dashboards/system";
            }
            {
              name = "network-dashboard";
              orgId = 1;
              folder = "Network";
              type = "file";
              disableDeletion = false;
              editable = true;
              allowUIUpdates = true;
              options.path = "/etc/grafana-dashboards/network";
            }
            {
              name = "systemd-dashboard";
              orgId = 1;
              folder = "Systemd";
              type = "file";
              disableDeletion = false;
              editable = true;
              allowUIUpdates = true;
              options.path = "/etc/grafana-dashboards/systemd";
            }
            {
              name = "smart-dashboard";
              orgId = 1;
              folder = "Storage";
              type = "file";
              disableDeletion = false;
              editable = true;
              allowUIUpdates = true;
              options.path = "/etc/grafana-dashboards/smart";
            }
          ]
          ++
            # NUT dashboard
            (lib.optionals cfg.enableUps [
              {
                name = "nut-dashboard";
                orgId = 1;
                folder = "UPS";
                type = "file";
                disableDeletion = false;
                editable = true;
                allowUIUpdates = true;
                options.path = "/etc/grafana-dashboards/nut";
              }
            ])
          ++
            # GPU dashboard
            (lib.optionals cfg.enableGpu [
              {
                name = "gpu-dashboard";
                orgId = 1;
                folder = "GPU";
                type = "file";
                disableDeletion = false;
                editable = true;
                allowUIUpdates = true;
                options.path = "/etc/grafana-dashboards/gpu";
              }
            ]);
      };
    };

    # ===================
    # UPS Monitoring (NUT)
    # ===================
    power.ups = lib.mkIf cfg.enableUps {
      enable = true;
      mode = "netserver";
      ups.eaton5sc = {
        driver = "usbhid-ups";
        port = "auto";
        directives = [
          "vendorid = 0463"
          "productid = ffff"
        ];
        description = "Eaton 5SC1000";
      };

      upsd.listen = [
        {
          address = "0.0.0.0";
          port = 1618;
        }
      ];

      upsmon.monitor.eaton5sc = {
        user = "monuser";
        system = "eaton5sc@127.0.0.1:1618";
        type = "primary";
      };

      users.monuser = {
        passwordFile = "/etc/nut/mon.pw";
        upsmon = "primary";
      };

      openFirewall = true;
    };

    environment.etc."nut/mon.pw" = lib.mkIf cfg.enableUps {
      text = "password";
      mode = "0600";
      user = "root";
      group = "nut";
    };

    services.prometheus.exporters.nut = lib.mkIf cfg.enableUps {
      enable = true;
      nutServer = "127.0.0.1";
      extraFlags = [
        "--nut.serverport=1618"
        "--nut.vars_enable="
      ];
      port = 16180;
      listenAddress = "0.0.0.0";
    };

    # UPS logging with persistent journal
    systemd.services.upsmon.serviceConfig.LogNamespace = lib.mkIf cfg.enableUps "power";
    systemd.services.upsd.serviceConfig.LogNamespace = lib.mkIf cfg.enableUps "power";
    systemd.services."nut-driver@".serviceConfig.LogNamespace = lib.mkIf cfg.enableUps "power";

    environment.etc."systemd/journald@power.conf" = lib.mkIf cfg.enableUps {
      text = ''
        [Journal]
        MaxRetentionSec=infinity
        SystemMaxUse=500G
        Storage=persistent
      '';
    };

    # UPS Dashboard
    environment.etc."grafana-dashboards/nut/nut-dashboard.json" = lib.mkIf cfg.enableUps {
      text = builtins.toJSON dashboards.ups;
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };

    # ===================
    # GPU Monitoring (DCGM)
    # ===================

    # DCGM Host Engine daemon - required for dcgm-exporter
    systemd.services.nv-hostengine = lib.mkIf cfg.enableGpu {
      description = "NVIDIA DCGM Host Engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.dcgm}/bin/nv-hostengine -n";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # DCGM Exporter - exports GPU metrics to Prometheus
    systemd.services.dcgm-exporter = lib.mkIf cfg.enableGpu {
      description = "NVIDIA DCGM Prometheus Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "nv-hostengine.service" ];
      requires = [ "nv-hostengine.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.prometheus-dcgm-exporter}/bin/dcgm-exporter -f ${pkgs.prometheus-dcgm-exporter}/etc/default-counters.csv";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # GPU Dashboard
    environment.etc."grafana-dashboards/gpu/dcgm-dashboard.json" = lib.mkIf cfg.enableGpu {
      text = builtins.toJSON dashboards.gpu;
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };

    # ===================
    # System Dashboard
    # ===================
    environment.etc."grafana-dashboards/system/system-dashboard.json" = {
      text = builtins.toJSON dashboards.system;
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };

    # ===================
    # Systemd Dashboard
    # ===================
    environment.etc."grafana-dashboards/systemd/systemd-dashboard.json" = {
      text = builtins.toJSON dashboards.systemd;
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };

    # ===================
    # Network Dashboard
    # ===================
    environment.etc."grafana-dashboards/network/network-dashboard.json" = {
      text = builtins.toJSON dashboards.network;
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };

    # ===================
    # SMART Dashboard
    # ===================
    environment.etc."grafana-dashboards/smart/smart-dashboard.json" = {
      text = builtins.toJSON dashboards.smart;
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };
  };
}

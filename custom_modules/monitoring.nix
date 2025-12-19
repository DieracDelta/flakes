{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.custom_modules.monitoring;
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
      scrapeConfigs =
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
        org_role = "Viewer";
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
          # NUT dashboard
          (lib.optionals cfg.enableUps [
            {
              name = "nut-dashboard";
              orgId = 1;
              folder = "UPS";
              type = "file";
              disableDeletion = false;
              editable = true;
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

    # NUT dashboard - Custom dashboard for Eaton 5SC UPS
    environment.etc."grafana-dashboards/nut/nut-dashboard.json" = lib.mkIf cfg.enableUps {
      text = builtins.toJSON {
        annotations.list = [];
        editable = true;
        fiscalYearStartMonth = 0;
        graphTooltip = 0;
        links = [];
        panels = [
          # Row 0: Power Status Timeline
          {
            type = "state-timeline";
            title = "Power Outage History";
            description = "Shows when the UPS was on battery power (power outage) vs online (AC power)";
            gridPos = { h = 6; w = 24; x = 0; y = 0; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "red"; value = 1; }
              ];
              mappings = [
                { type = "value"; options."0" = { text = "Online (AC)"; color = "green"; }; }
                { type = "value"; options."1" = { text = "On Battery"; color = "red"; }; }
              ];
              custom.fillOpacity = 80;
            };
            options = {
              showValue = "auto";
              alignValue = "center";
              mergeValues = true;
              rowHeight = 0.9;
              legend = { displayMode = "list"; placement = "bottom"; };
            };
            targets = [{
              expr = ''network_ups_tools_ups_status{flag="OB"}'';
              legendFormat = "Power Status";
              refId = "A";
            }];
          }
          # Row 1: Status gauges
          {
            type = "gauge";
            title = "Battery Charge";
            gridPos = { h = 8; w = 6; x = 0; y = 6; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "red"; value = null; }
                { color = "orange"; value = 30; }
                { color = "yellow"; value = 50; }
                { color = "green"; value = 80; }
              ];
              unit = "percent";
              min = 0;
              max = 100;
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; };
            targets = [{ expr = "network_ups_tools_battery_charge"; refId = "A"; }];
          }
          {
            type = "gauge";
            title = "UPS Load";
            gridPos = { h = 8; w = 6; x = 6; y = 6; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 50; }
                { color = "orange"; value = 75; }
                { color = "red"; value = 90; }
              ];
              unit = "percent";
              min = 0;
              max = 100;
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; };
            targets = [{ expr = "network_ups_tools_ups_load"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "Runtime Remaining";
            gridPos = { h = 8; w = 6; x = 12; y = 6; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "red"; value = null; }
                { color = "orange"; value = 300; }
                { color = "yellow"; value = 600; }
                { color = "green"; value = 1200; }
              ];
              unit = "s";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "network_ups_tools_battery_runtime"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "Power Draw";
            gridPos = { h = 8; w = 6; x = 18; y = 6; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = {
              color.mode = "palette-classic";
              unit = "watt";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "network_ups_tools_ups_realpower"; legendFormat = "Real Power"; refId = "A"; }];
          }
          # Row 2: Voltage and current graphs
          {
            type = "timeseries";
            title = "Input/Output Voltage";
            gridPos = { h = 8; w = 12; x = 0; y = 14; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = { unit = "volt"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "network_ups_tools_input_voltage"; legendFormat = "Input"; refId = "A"; }
              { expr = "network_ups_tools_output_voltage"; legendFormat = "Output"; refId = "B"; }
            ];
          }
          {
            type = "timeseries";
            title = "Battery Voltage";
            gridPos = { h = 8; w = 12; x = 12; y = 14; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = { unit = "volt"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "network_ups_tools_battery_voltage"; legendFormat = "Battery"; refId = "A"; }
              { expr = "network_ups_tools_battery_voltage_nominal"; legendFormat = "Nominal"; refId = "B"; }
            ];
          }
          # Row 3: Load and runtime over time
          {
            type = "timeseries";
            title = "UPS Load Over Time";
            gridPos = { h = 8; w = 12; x = 0; y = 22; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [{ expr = "network_ups_tools_ups_load"; legendFormat = "Load %"; refId = "A"; }];
          }
          {
            type = "timeseries";
            title = "Power Consumption";
            gridPos = { h = 8; w = 12; x = 12; y = 22; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = { unit = "watt"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "network_ups_tools_ups_realpower"; legendFormat = "Real Power (W)"; refId = "A"; }
              { expr = "network_ups_tools_ups_power"; legendFormat = "Apparent Power (VA)"; refId = "B"; }
            ];
          }
          # Row 4: Battery and efficiency
          {
            type = "timeseries";
            title = "Battery Charge Over Time";
            gridPos = { h = 8; w = 12; x = 0; y = 30; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [{ expr = "network_ups_tools_battery_charge"; legendFormat = "Charge %"; refId = "A"; }];
          }
          {
            type = "timeseries";
            title = "UPS Efficiency";
            gridPos = { h = 8; w = 12; x = 12; y = 30; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [{ expr = "network_ups_tools_ups_efficiency"; legendFormat = "Efficiency %"; refId = "A"; }];
          }
          # Row 5: Frequency
          {
            type = "timeseries";
            title = "Input/Output Frequency";
            gridPos = { h = 8; w = 24; x = 0; y = 38; };
            datasource = { type = "prometheus"; uid = "Prometheus"; };
            fieldConfig.defaults = { unit = "hertz"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "network_ups_tools_input_frequency"; legendFormat = "Input"; refId = "A"; }
              { expr = "network_ups_tools_output_frequency"; legendFormat = "Output"; refId = "B"; }
            ];
          }
        ];
        refresh = "30s";
        schemaVersion = 39;
        tags = ["ups" "nut" "eaton"];
        templating.list = [];
        time = { from = "now-6h"; to = "now"; };
        timepicker = {};
        timezone = "browser";
        title = "Eaton 5SC UPS";
        uid = "eaton-5sc-ups";
        version = 1;
      };
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

    # GPU dashboard - NVIDIA DCGM Exporter Dashboard (ID 12239)
    environment.etc."grafana-dashboards/gpu/dcgm-dashboard.json" = lib.mkIf cfg.enableGpu {
      text =
        let
          raw = builtins.fetchurl {
            url = "https://grafana.com/api/dashboards/12239/revisions/2/download";
            sha256 = "1zjd5qgnhz1g9lyvxri3jgibhqgm3ps9a80k85k7fabji27g2r3r";
          };
          # Replace datasource placeholder with our Prometheus datasource
          fixed = builtins.replaceStrings [ "\${DS_PROMETHEUS}" ] [ "Prometheus" ] (builtins.readFile raw);
        in
        fixed;
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };
  };
}

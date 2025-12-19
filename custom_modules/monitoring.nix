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
      scrapeConfigs =
        # Node exporter scrape config (always enabled)
        [
          {
            job_name = "node";
            static_configs = [
              { targets = [ "127.0.0.1:9100" ]; }
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
          # System dashboard (always enabled)
          [
            {
              name = "system-dashboard";
              orgId = 1;
              folder = "System";
              type = "file";
              disableDeletion = false;
              editable = true;
              options.path = "/etc/grafana-dashboards/system";
            }
            {
              name = "network-dashboard";
              orgId = 1;
              folder = "Network";
              type = "file";
              disableDeletion = false;
              editable = true;
              options.path = "/etc/grafana-dashboards/network";
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
datasource = "Prometheus";
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
            datasource = "Prometheus";
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
            datasource = "Prometheus";
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
            datasource = "Prometheus";
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
            datasource = "Prometheus";
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
            datasource = "Prometheus";
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
            datasource = "Prometheus";
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
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [{ expr = "network_ups_tools_ups_load"; legendFormat = "Load %"; refId = "A"; }];
          }
          {
            type = "timeseries";
            title = "Power Consumption";
            gridPos = { h = 8; w = 12; x = 12; y = 22; };
            datasource = "Prometheus";
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
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [{ expr = "network_ups_tools_battery_charge"; legendFormat = "Charge %"; refId = "A"; }];
          }
          {
            type = "timeseries";
            title = "UPS Efficiency";
            gridPos = { h = 8; w = 12; x = 12; y = 30; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [{ expr = "network_ups_tools_ups_efficiency"; legendFormat = "Efficiency %"; refId = "A"; }];
          }
          # Row 5: Frequency
          {
            type = "timeseries";
            title = "Input/Output Frequency";
            gridPos = { h = 8; w = 24; x = 0; y = 38; };
            datasource = "Prometheus";
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

    # GPU dashboard - Custom NVIDIA RTX 4090 Dashboard
    environment.etc."grafana-dashboards/gpu/dcgm-dashboard.json" = lib.mkIf cfg.enableGpu {
      text = builtins.toJSON {
        annotations.list = [];
        editable = true;
        fiscalYearStartMonth = 0;
        graphTooltip = 0;
        links = [];
        panels = [
          # Row 1: Status gauges
          {
            type = "gauge";
            title = "GPU Temperature";
            gridPos = { h = 8; w = 5; x = 0; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 60; }
                { color = "orange"; value = 75; }
                { color = "red"; value = 85; }
              ];
              unit = "celsius";
              min = 0;
              max = 100;
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; };
            targets = [{ expr = "DCGM_FI_DEV_GPU_TEMP"; refId = "A"; }];
          }
          {
            type = "gauge";
            title = "GPU Utilization";
            gridPos = { h = 8; w = 5; x = 5; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 70; }
                { color = "orange"; value = 85; }
                { color = "red"; value = 95; }
              ];
              unit = "percent";
              min = 0;
              max = 100;
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; };
            targets = [{ expr = "DCGM_FI_DEV_GPU_UTIL"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "Power Draw";
            gridPos = { h = 8; w = 5; x = 10; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 200; }
                { color = "orange"; value = 350; }
                { color = "red"; value = 400; }
              ];
              unit = "watt";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "DCGM_FI_DEV_POWER_USAGE"; legendFormat = "Power"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "Total Energy";
            description = "Total energy consumed by GPU since driver load";
            gridPos = { h = 8; w = 5; x = 15; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "palette-classic";
              unit = "kwatth";
              decimals = 2;
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            # DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION is in millijoules, convert to kWh
            # 1 kWh = 3,600,000,000 mJ
            targets = [{ expr = "DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION / 3600000000"; legendFormat = "Total"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "VRAM Used";
            gridPos = { h = 8; w = 4; x = 20; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 16000; }
                { color = "orange"; value = 20000; }
                { color = "red"; value = 23000; }
              ];
              unit = "decmbytes";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "DCGM_FI_DEV_FB_USED"; legendFormat = "Used"; refId = "A"; }];
          }
          # Row 2: Utilization over time
          {
            type = "timeseries";
            title = "GPU Utilization Over Time";
            gridPos = { h = 8; w = 12; x = 0; y = 8; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "DCGM_FI_DEV_GPU_UTIL"; legendFormat = "GPU Core"; refId = "A"; }
              { expr = "DCGM_FI_DEV_MEM_COPY_UTIL"; legendFormat = "Memory Copy"; refId = "B"; }
            ];
          }
          {
            type = "timeseries";
            title = "Encoder/Decoder Utilization";
            gridPos = { h = 8; w = 12; x = 12; y = 8; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "DCGM_FI_DEV_ENC_UTIL"; legendFormat = "Encoder (NVENC)"; refId = "A"; }
              { expr = "DCGM_FI_DEV_DEC_UTIL"; legendFormat = "Decoder (NVDEC)"; refId = "B"; }
            ];
          }
          # Row 3: Temperature and Power
          {
            type = "timeseries";
            title = "Temperature Over Time";
            gridPos = { h = 8; w = 12; x = 0; y = 16; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "celsius"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "DCGM_FI_DEV_GPU_TEMP"; legendFormat = "GPU"; refId = "A"; }
            ];
          }
          {
            type = "timeseries";
            title = "Power Consumption Over Time";
            gridPos = { h = 8; w = 12; x = 12; y = 16; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "watt"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "DCGM_FI_DEV_POWER_USAGE"; legendFormat = "Power Draw"; refId = "A"; }
            ];
          }
          # Row 4: Memory
          {
            type = "timeseries";
            title = "VRAM Usage Over Time";
            gridPos = { h = 8; w = 12; x = 0; y = 24; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "decmbytes"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "DCGM_FI_DEV_FB_USED"; legendFormat = "Used"; refId = "A"; }
              { expr = "DCGM_FI_DEV_FB_FREE"; legendFormat = "Free"; refId = "B"; }
              { expr = "DCGM_FI_DEV_FB_RESERVED"; legendFormat = "Reserved"; refId = "C"; }
            ];
          }
          {
            type = "timeseries";
            title = "Clock Speeds";
            gridPos = { h = 8; w = 12; x = 12; y = 24; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "clockmhz"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "DCGM_FI_DEV_SM_CLOCK"; legendFormat = "SM Clock"; refId = "A"; }
              { expr = "DCGM_FI_DEV_MEM_CLOCK"; legendFormat = "Memory Clock"; refId = "B"; }
            ];
          }
          # Row 5: Energy consumption (counter)
          {
            type = "timeseries";
            title = "Energy Consumption Rate";
            description = "Rate of energy consumption (derivative of total energy counter)";
            gridPos = { h = 8; w = 24; x = 0; y = 32; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "watt"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "rate(DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION[5m]) / 1000"; legendFormat = "Energy Rate (W)"; refId = "A"; }
            ];
          }
          # Row 6: PCIe and Errors
          {
            type = "stat";
            title = "PCIe Replay Errors";
            gridPos = { h = 4; w = 6; x = 0; y = 40; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 1; }
                { color = "red"; value = 100; }
              ];
              unit = "none";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "DCGM_FI_DEV_PCIE_REPLAY_COUNTER"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "XID Errors";
            gridPos = { h = 4; w = 6; x = 6; y = 40; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "red"; value = 1; }
              ];
              unit = "none";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "DCGM_FI_DEV_XID_ERRORS"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "Uncorrectable Row Remaps";
            gridPos = { h = 4; w = 6; x = 12; y = 40; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 1; }
                { color = "red"; value = 5; }
              ];
              unit = "none";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "DCGM_FI_DEV_UNCORRECTABLE_REMAPPED_ROWS"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "Correctable Row Remaps";
            gridPos = { h = 4; w = 6; x = 18; y = 40; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 1; }
                { color = "orange"; value = 10; }
              ];
              unit = "none";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "DCGM_FI_DEV_CORRECTABLE_REMAPPED_ROWS"; refId = "A"; }];
          }
        ];
        refresh = "30s";
        schemaVersion = 39;
        tags = ["gpu" "nvidia" "dcgm" "rtx4090"];
        templating.list = [];
        time = { from = "now-6h"; to = "now"; };
        timepicker = {};
        timezone = "browser";
        title = "NVIDIA RTX 4090";
        uid = "nvidia-rtx-4090";
        version = 1;
      };
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };

    # ===================
    # System Dashboard
    # ===================
    environment.etc."grafana-dashboards/system/system-dashboard.json" = {
      text = builtins.toJSON {
        annotations.list = [];
        editable = true;
        fiscalYearStartMonth = 0;
        graphTooltip = 0;
        links = [];
        panels = [
          # Row 1: CPU Overview
          {
            type = "gauge";
            title = "CPU Usage";
            gridPos = { h = 8; w = 4; x = 0; y = 0; };
            datasource = "Prometheus";
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
            targets = [{ expr = "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "CPU Power";
            description = "Total CPU package power from Energy sensors";
            gridPos = { h = 8; w = 4; x = 4; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 65; }
                { color = "orange"; value = 105; }
                { color = "red"; value = 142; }
              ];
              unit = "watt";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "rate(node_hwmon_energy_joule_total{chip=\"platform_zenergy_0\", sensor=\"energy17\"}[5m])"; legendFormat = "Package Power"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "CPU Temp";
            gridPos = { h = 8; w = 4; x = 8; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 60; }
                { color = "orange"; value = 75; }
                { color = "red"; value = 85; }
              ];
              unit = "celsius";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "node_hwmon_temp_celsius{chip=~\".*k10temp.*|.*thermal_zone.*|.*asus_ec.*\", sensor=\"temp1\"}"; legendFormat = "Tctl"; refId = "A"; }];
          }
          {
            type = "gauge";
            title = "Memory Usage";
            gridPos = { h = 8; w = 4; x = 12; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 60; }
                { color = "orange"; value = 80; }
                { color = "red"; value = 90; }
              ];
              unit = "percent";
              min = 0;
              max = 100;
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; };
            targets = [{ expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "Memory Used";
            gridPos = { h = 8; w = 4; x = 16; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "palette-classic";
              unit = "bytes";
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes"; legendFormat = "Used"; refId = "A"; }];
          }
          {
            type = "stat";
            title = "Load Average (1m)";
            gridPos = { h = 8; w = 4; x = 20; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 8; }
                { color = "orange"; value = 16; }
                { color = "red"; value = 24; }
              ];
              decimals = 2;
            };
            options = { reduceOptions = { calcs = ["lastNotNull"]; }; colorMode = "value"; };
            targets = [{ expr = "node_load1"; refId = "A"; }];
          }
          # Row 2: CPU Usage and Power Over Time
          {
            type = "timeseries";
            title = "CPU Usage Over Time";
            gridPos = { h = 8; w = 8; x = 0; y = 8; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; max = 100; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"; legendFormat = "Total"; refId = "A"; }
              { expr = "avg(irate(node_cpu_seconds_total{mode=\"user\"}[5m])) * 100"; legendFormat = "User"; refId = "B"; }
              { expr = "avg(irate(node_cpu_seconds_total{mode=\"system\"}[5m])) * 100"; legendFormat = "System"; refId = "C"; }
              { expr = "avg(irate(node_cpu_seconds_total{mode=\"iowait\"}[5m])) * 100"; legendFormat = "IOWait"; refId = "D"; }
            ];
          }
          {
            type = "timeseries";
            title = "CPU Power Over Time";
            gridPos = { h = 8; w = 8; x = 8; y = 8; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "watt"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "rate(node_hwmon_energy_joule_total{chip=\"platform_zenergy_0\", sensor=\"energy17\"}[5m])"; legendFormat = "Package Power"; refId = "A"; }
              { expr = "sum(rate(node_hwmon_energy_joule_total{chip=\"platform_zenergy_0\", sensor!=\"energy17\"}[5m]))"; legendFormat = "Core Power"; refId = "B"; }
            ];
          }
          {
            type = "timeseries";
            title = "Cumulative Energy (kWh)";
            gridPos = { h = 8; w = 8; x = 16; y = 8; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "kWh"; };
            options = { 
              legend = { 
                displayMode = "table"; 
                placement = "bottom"; 
                calcs = ["diff"]; 
              }; 
            };
            targets = [
              { expr = "node_hwmon_energy_joule_total{chip=\"platform_zenergy_0\", sensor=\"energy17\"} / 3600000"; legendFormat = "Total Energy"; refId = "A"; }
            ];
          }

          # Row 3: Temperature and Frequency
          {
            type = "timeseries";
            title = "CPU Temperature Over Time";
            gridPos = { h = 8; w = 12; x = 0; y = 16; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "celsius"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "node_hwmon_temp_celsius{chip=~\".*k10temp.*|.*thermal_zone.*|.*asus_ec.*\", sensor=\"temp1\"}"; legendFormat = "Tctl"; refId = "A"; }
              { expr = "node_hwmon_temp_celsius{chip=~\".*k10temp.*|.*thermal_zone.*|.*asus_ec.*\", sensor=\"temp3\"}"; legendFormat = "Tccd1"; refId = "B"; }
              { expr = "node_hwmon_temp_celsius{chip=~\".*k10temp.*|.*thermal_zone.*|.*asus_ec.*\", sensor=\"temp4\"}"; legendFormat = "Tccd2"; refId = "C"; }
            ];
          }
          {
            type = "timeseries";
            title = "CPU Frequency";
            gridPos = { h = 8; w = 12; x = 12; y = 16; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "hertz"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "avg(node_cpu_scaling_frequency_hertz)"; legendFormat = "Average"; refId = "A"; }
              { expr = "max(node_cpu_scaling_frequency_hertz)"; legendFormat = "Max"; refId = "B"; }
              { expr = "min(node_cpu_scaling_frequency_hertz)"; legendFormat = "Min"; refId = "C"; }
            ];
          }
          # Row 4: Memory
          {
            type = "timeseries";
            title = "Memory Usage Over Time";
            gridPos = { h = 8; w = 12; x = 0; y = 24; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "bytes"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes"; legendFormat = "Used"; refId = "A"; }
              { expr = "node_memory_Cached_bytes"; legendFormat = "Cached"; refId = "B"; }
              { expr = "node_memory_Buffers_bytes"; legendFormat = "Buffers"; refId = "C"; }
              { expr = "node_memory_MemFree_bytes"; legendFormat = "Free"; refId = "D"; }
            ];
          }
          {
            type = "timeseries";
            title = "Swap Usage";
            gridPos = { h = 8; w = 12; x = 12; y = 24; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "bytes"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes"; legendFormat = "Swap Used"; refId = "A"; }
              { expr = "node_memory_SwapTotal_bytes"; legendFormat = "Swap Total"; refId = "B"; }
            ];
          }
          # Row 5: Disk I/O
          {
            type = "timeseries";
            title = "Disk I/O Throughput";
            gridPos = { h = 8; w = 12; x = 0; y = 32; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "Bps"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "sum(irate(node_disk_read_bytes_total{device=~\"nvme.*|sd.*\"}[5m]))"; legendFormat = "Read"; refId = "A"; }
              { expr = "sum(irate(node_disk_written_bytes_total{device=~\"nvme.*|sd.*\"}[5m]))"; legendFormat = "Write"; refId = "B"; }
            ];
          }
          {
            type = "timeseries";
            title = "Disk I/O Operations";
            gridPos = { h = 8; w = 12; x = 12; y = 32; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "iops"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "sum(irate(node_disk_reads_completed_total{device=~\"nvme.*|sd.*\"}[5m]))"; legendFormat = "Reads"; refId = "A"; }
              { expr = "sum(irate(node_disk_writes_completed_total{device=~\"nvme.*|sd.*\"}[5m]))"; legendFormat = "Writes"; refId = "B"; }
            ];
          }
          # Row 6: NVMe Temperatures
          {
            type = "timeseries";
            title = "NVMe Temperatures";
            gridPos = { h = 8; w = 24; x = 0; y = 40; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "celsius"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "node_hwmon_temp_celsius{chip=~\"nvme.*\"}"; legendFormat = "{{chip}}"; refId = "A"; }
            ];
          }
          # Row 7: Network
          {
            type = "timeseries";
            title = "Network Traffic";
            gridPos = { h = 8; w = 12; x = 0; y = 48; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "bps"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "sum(irate(node_network_receive_bytes_total{device!~\"lo|veth.*|br.*|docker.*\"}[5m])) * 8"; legendFormat = "Receive"; refId = "A"; }
              { expr = "sum(irate(node_network_transmit_bytes_total{device!~\"lo|veth.*|br.*|docker.*\"}[5m])) * 8"; legendFormat = "Transmit"; refId = "B"; }
            ];
          }
          {
            type = "timeseries";
            title = "Network Errors & Drops";
            gridPos = { h = 8; w = 12; x = 12; y = 48; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "pps"; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "sum(irate(node_network_receive_drop_total{device!~\"lo|veth.*\"}[5m]))"; legendFormat = "RX Drops"; refId = "A"; }
              { expr = "sum(irate(node_network_transmit_drop_total{device!~\"lo|veth.*\"}[5m]))"; legendFormat = "TX Drops"; refId = "B"; }
              { expr = "sum(irate(node_network_receive_errs_total{device!~\"lo|veth.*\"}[5m]))"; legendFormat = "RX Errors"; refId = "C"; }
              { expr = "sum(irate(node_network_transmit_errs_total{device!~\"lo|veth.*\"}[5m]))"; legendFormat = "TX Errors"; refId = "D"; }
            ];
          }
          # Row 8: Filesystem
          {
            type = "bargauge";
            title = "Filesystem Usage";
            gridPos = { h = 8; w = 24; x = 0; y = 56; };
            datasource = "Prometheus";
            fieldConfig.defaults = {
              color.mode = "thresholds";
              thresholds.mode = "percentage";
              thresholds.steps = [
                { color = "green"; value = null; }
                { color = "yellow"; value = 70; }
                { color = "orange"; value = 85; }
                { color = "red"; value = 95; }
              ];
              unit = "percent";
              min = 0;
              max = 100;
            };
            options = {
              displayMode = "lcd";
              orientation = "horizontal";
              reduceOptions = { calcs = ["lastNotNull"]; };
            };
            targets = [{
              expr = "(1 - (node_filesystem_avail_bytes{fstype=~\"ext4|xfs|btrfs|zfs\",mountpoint!~\"/boot.*\"} / node_filesystem_size_bytes{fstype=~\"ext4|xfs|btrfs|zfs\",mountpoint!~\"/boot.*\"})) * 100";
              legendFormat = "{{mountpoint}}";
              refId = "A";
            }];
          }
          # Row 9: System Pressure (PSI)
          {
            type = "timeseries";
            title = "CPU Pressure";
            gridPos = { h = 6; w = 8; x = 0; y = 64; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "irate(node_pressure_cpu_waiting_seconds_total[5m]) * 100"; legendFormat = "Wait"; refId = "A"; }
            ];
          }
          {
            type = "timeseries";
            title = "Memory Pressure";
            gridPos = { h = 6; w = 8; x = 8; y = 64; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "irate(node_pressure_memory_waiting_seconds_total[5m]) * 100"; legendFormat = "Wait"; refId = "A"; }
            ];
          }
          {
            type = "timeseries";
            title = "I/O Pressure";
            gridPos = { h = 6; w = 8; x = 16; y = 64; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "percent"; min = 0; };
            options = { legend = { displayMode = "list"; placement = "bottom"; }; };
            targets = [
              { expr = "irate(node_pressure_io_waiting_seconds_total[5m]) * 100"; legendFormat = "Wait"; refId = "A"; }
            ];
          }
        ];
        refresh = "30s";
        schemaVersion = 39;
        tags = ["system" "node" "cpu" "memory" "disk" "network"];
        templating.list = [];
        time = { from = "now-6h"; to = "now"; };
        timepicker = {};
        timezone = "browser";
        title = "System Overview";
        uid = "system-overview";
        version = 1;
      };
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };

    # ===================
    # Network Dashboard
    # ===================
    environment.etc."grafana-dashboards/network/network-dashboard.json" = {
      text = builtins.toJSON {
        annotations.list = [];
        editable = true;
        fiscalYearStartMonth = 0;
        graphTooltip = 0;
        links = [];
        panels = [
          # Row 1: Systemd Services
          {
            type = "timeseries";
            title = "Top Systemd Services (Download)";
            gridPos = { h = 10; w = 12; x = 0; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "Bps"; };
            options = { legend = { displayMode = "table"; placement = "right"; calcs = ["mean" "max" "last"]; }; };
            targets = [
              { expr = "topk(10, irate(systemd_unit_ingress_bytes[5m]))"; legendFormat = "{{unit}}"; refId = "A"; }
            ];
          }
          {
            type = "timeseries";
            title = "Top Systemd Services (Upload)";
            gridPos = { h = 10; w = 12; x = 12; y = 0; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "Bps"; };
            options = { legend = { displayMode = "table"; placement = "right"; calcs = ["mean" "max" "last"]; }; };
            targets = [
              { expr = "topk(10, irate(systemd_unit_egress_bytes[5m]))"; legendFormat = "{{unit}}"; refId = "A"; }
            ];
          }
          # Row 2: Nethogs Processes
          {
            type = "timeseries";
            title = "Top Processes (Download)";
            gridPos = { h = 10; w = 12; x = 0; y = 10; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "Bps"; };
            options = { legend = { displayMode = "table"; placement = "right"; calcs = ["mean" "max" "last"]; }; };
            targets = [
              { expr = "topk(10, rate(nethogs_process_download_bytes{user!=\"\"}[5m]))"; legendFormat = "{{process}} ({{user}})"; refId = "A"; }
            ];
          }
          {
            type = "timeseries";
            title = "Top Processes (Upload)";
            gridPos = { h = 10; w = 12; x = 12; y = 10; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "Bps"; };
            options = { legend = { displayMode = "table"; placement = "right"; calcs = ["mean" "max" "last"]; }; };
            targets = [
              { expr = "topk(10, rate(nethogs_process_upload_bytes{user!=\"\"}[5m]))"; legendFormat = "{{process}} ({{user}})"; refId = "A"; }
            ];
          }
          # Row 3: Cumulative Usage
          {
            type = "timeseries";
            title = "Total System Data Usage (Cumulative)";
            gridPos = { h = 10; w = 8; x = 0; y = 20; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "decbytes"; };
            options = { 
              legend = { 
                displayMode = "table"; 
                placement = "bottom"; 
                calcs = ["diff"]; 
              }; 
            };
            targets = [
              { expr = "sum(node_network_receive_bytes_total{device!~\"lo|veth.*|br.*|docker.*\"})"; legendFormat = "Total Download"; refId = "A"; }
              { expr = "sum(node_network_transmit_bytes_total{device!~\"lo|veth.*|br.*|docker.*\"})"; legendFormat = "Total Upload"; refId = "B"; }
            ];
          }
          {
            type = "bargauge";
            title = "Top Processes by Data Usage (In Selected Range)";
            description = "Shows the total data (Download + Upload) used by the top processes within the currently selected time window.";
            gridPos = { h = 10; w = 8; x = 8; y = 20; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "decbytes"; };
            options = {
              displayMode = "gradient";
              orientation = "horizontal";
              reduceOptions = { calcs = ["max"]; };
            };
            targets = [
              { 
                # Sum of download + upload per process
                expr = "topk(10, increase(nethogs_process_download_bytes{user!=\"\"}[$__range]) + increase(nethogs_process_upload_bytes{user!=\"\"}[$__range]))"; 
                legendFormat = "{{process}} ({{user}})"; 
                refId = "A"; 
              }
            ];
          }
          {
            type = "bargauge";
            title = "Top Systemd Services by Data Usage (In Selected Range)";
            description = "Shows the total data (Ingress + Egress) used by the top systemd services within the currently selected time window.";
            gridPos = { h = 10; w = 8; x = 16; y = 20; };
            datasource = "Prometheus";
            fieldConfig.defaults = { unit = "decbytes"; };
            options = {
              displayMode = "gradient";
              orientation = "horizontal";
              reduceOptions = { calcs = ["max"]; };
            };
            targets = [
              { 
                # Sum of ingress + egress per unit
                expr = "topk(10, increase(systemd_unit_ingress_bytes[$__range]) + increase(systemd_unit_egress_bytes[$__range]))"; 
                legendFormat = "{{unit}}"; 
                refId = "A"; 
              }
            ];
          }
        ];
        refresh = "30s";
        schemaVersion = 39;
        tags = ["network" "systemd" "nethogs"];
        templating.list = [];
        time = { from = "now-1h"; to = "now"; };
        timepicker = {};
        timezone = "browser";
        title = "Network Traffic Breakdown";
        uid = "network-breakdown";
        version = 1;
      };
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };
  };
}

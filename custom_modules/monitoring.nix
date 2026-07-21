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

  userCgroupIoCollector = pkgs.writeScript "prometheus-user-cgroup-io" ''
    #!${pkgs.python3}/bin/python3
    import glob
    import os
    import pwd
    import re
    import time
    from pathlib import Path

    output = Path(os.environ.get(
        "USER_CGROUP_IO_OUTPUT",
        "/var/lib/node_exporter/textfile_collector/user_cgroup_io.prom",
    ))
    cgroup_root = Path("/sys/fs/cgroup")
    metric_definitions = (
        ("rbytes", "user_cgroup_io_read_bytes_total", "Bytes read by a user cgroup from a physical block device."),
        ("wbytes", "user_cgroup_io_write_bytes_total", "Bytes written by a user cgroup to a physical block device."),
        ("rios", "user_cgroup_io_read_operations_total", "Read operations issued by a user cgroup to a physical block device."),
        ("wios", "user_cgroup_io_write_operations_total", "Write operations issued by a user cgroup to a physical block device."),
    )

    def escape_label(value):
        return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')

    def physical_device_name(major_minor):
        sys_device = Path("/sys/dev/block") / major_minor
        if not sys_device.exists():
            return None
        resolved = os.path.realpath(sys_device)
        if "/virtual/" in resolved:
            return None
        return os.path.basename(resolved)

    def read_scope(path, user, uid):
        rows = []
        try:
            stat_lines = (path / "io.stat").read_text().splitlines()
        except OSError:
            return rows

        for line in stat_lines:
            fields = line.split()
            if not fields:
                continue
            major_minor = fields[0]
            device = physical_device_name(major_minor)
            if device is None:
                continue
            counters = {}
            for field in fields[1:]:
                try:
                    key, value = field.split("=", 1)
                    counters[key] = int(value)
                except (ValueError, TypeError):
                    continue
            labels = (
                f'user="{escape_label(user)}",uid="{escape_label(uid)}",'
                f'cgroup="{escape_label(path.name)}",device="{escape_label(device)}",'
                f'major_minor="{escape_label(major_minor)}"'
            )
            for field, metric, _help in metric_definitions:
                if field in counters:
                    rows.append((metric, labels, counters[field]))
        return rows

    scopes = []
    for path_string in sorted(glob.glob(str(cgroup_root / "user.slice/user-*.slice"))):
        path = Path(path_string)
        match = re.fullmatch(r"user-(\d+)\.slice", path.name)
        if match is None:
            continue
        uid = int(match.group(1))
        try:
            user = pwd.getpwuid(uid).pw_name
        except KeyError:
            user = str(uid)
        scopes.append((path, user, uid))

    for scope_name, label in (("system.slice", "system"), ("machine.slice", "machines")):
        path = cgroup_root / scope_name
        if path.exists():
            scopes.append((path, label, label))

    lines = []
    for _field, metric, help_text in metric_definitions:
        lines.append(f"# HELP {metric} {help_text}")
        lines.append(f"# TYPE {metric} counter")
    for path, user, uid in scopes:
        for metric, labels, value in read_scope(path, user, uid):
            lines.append(f"{metric}{{{labels}}} {value}")
    lines.extend((
        "# HELP user_cgroup_io_collector_timestamp_seconds Unix timestamp of the last successful collection.",
        "# TYPE user_cgroup_io_collector_timestamp_seconds gauge",
        f"user_cgroup_io_collector_timestamp_seconds {time.time():.6f}",
    ))

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.{os.getpid()}.tmp")
    temporary.write_text("\n".join(lines) + "\n")
    os.chmod(temporary, 0o644)
    os.replace(temporary, output)
  '';
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

      # The default 15-day retention made historical disk-write accounting
      # impossible. Current usage projects to roughly 35 GiB for five years.
      retentionTime = "5y";

      # Physical whole-device writes from node_exporter's diskstats collector.
      # This covers NVMe and SATA disks and survives counter resets on reboot.
      # Exact calendar periods are calculated from the retained counter using
      # $__range.
      rules = [
        ''
          groups:
            - name: disk-io-aggregates
              interval: 5m
              rules:
                - record: node_disk_written_bytes_1d
                  expr: increase(node_disk_written_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[1d])
                - record: node_disk_written_bytes_7d
                  expr: increase(node_disk_written_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[7d])
                - record: node_disk_written_bytes_30d
                  expr: increase(node_disk_written_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[30d])
                - record: user_cgroup_io_write_bytes_per_second
                  expr: rate(user_cgroup_io_write_bytes_total[5m])
                - record: user_cgroup_io_write_operations_per_second
                  expr: rate(user_cgroup_io_write_operations_total[5m])
                - record: user_cgroup_io_written_bytes_1d
                  expr: increase(user_cgroup_io_write_bytes_total[1d])
        ''
      ];

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

    # node_exporter has no per-user disk collector. Export the recursive
    # cgroup-v2 counters from each user slice, plus system and machine slices,
    # through node_exporter's textfile collector.
    systemd.services.prometheus-user-cgroup-io = {
      description = "Export per-user cgroup disk I/O metrics for Prometheus";
      after = [ "systemd-tmpfiles-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = userCgroupIoCollector;
        User = "root";
        Group = "root";
        UMask = "0022";
        Nice = 10;
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelTunables = true;
        PrivateTmp = true;
        CapabilityBoundingSet = "";
        ReadWritePaths = [ "/var/lib/node_exporter/textfile_collector" ];
      };
    };

    systemd.timers.prometheus-user-cgroup-io = {
      description = "Collect per-user cgroup disk I/O metrics every minute";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* *:*:00";
        AccuracySec = "10s";
        Persistent = true;
      };
    };

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
      settings.security = {
        # Preserve Grafana's historical default during the 26.05 transition so
        # existing encrypted DB fields remain readable until a deliberate rotation.
        secret_key = "$__file{${config.services.grafana.dataDir}/secret_key}";
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
    systemd.services.grafana.preStart = lib.mkAfter ''
      if [ ! -s ${config.services.grafana.dataDir}/secret_key ]; then
        umask 077
        printf '%s\n' 'SW2YcwTIb9zpOOhoPsMm' > ${config.services.grafana.dataDir}/secret_key
      fi
    '';

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

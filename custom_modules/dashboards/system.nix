# System Dashboard - CPU, Memory, Disk, Network overview
{
  annotations.list = [ ];
  editable = true;
  fiscalYearStartMonth = 0;
  graphTooltip = 0;
  links = [ ];
  panels = [
    # Row 1: CPU Overview
    {
      type = "gauge";
      title = "CPU Usage";
      gridPos = {
        h = 8;
        w = 4;
        x = 0;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "yellow";
            value = 50;
          }
          {
            color = "orange";
            value = 75;
          }
          {
            color = "red";
            value = 90;
          }
        ];
        unit = "percent";
        min = 0;
        max = 100;
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
      };
      targets = [
        {
          expr = "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Total CPU Energy";
      description = "Total CPU energy consumed over time range";
      datasource = {
        type = "prometheus";
        uid = "PBFA97CFB590B2093";
      };
      gridPos = {
        h = 8;
        w = 4;
        x = 4;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "kwatth";
        decimals = 2;
        mappings = [];
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "green";
              value = 0;
            }
            {
              color = "red";
              value = 80;
            }
          ];
        };
      };
      fieldConfig.overrides = [];
      options = {
        colorMode = "value";
        graphMode = "area";
        justifyMode = "auto";
        orientation = "auto";
        percentChangeColorMode = "standard";
        reduceOptions = {
          calcs = [ "sum" ];
          fields = "";
          values = false;
        };
        showPercentChange = false;
        textMode = "auto";
        wideLayout = true;
      };
      pluginVersion = "12.3.0";
      targets = [
        {
          editorMode = "code";
          exemplar = false;
          expr = "rate(node_hwmon_energy_joule_total{chip=\"platform_zenergy_0\", sensor=\"energy17\"}[5m])*$__interval_ms/(1000*3.6E6)";
          instant = false;
          legendFormat = "Total";
          range = true;
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "CPU Temp";
      gridPos = {
        h = 8;
        w = 4;
        x = 8;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "yellow";
            value = 60;
          }
          {
            color = "orange";
            value = 75;
          }
          {
            color = "red";
            value = 85;
          }
        ];
        unit = "celsius";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "node_hwmon_temp_celsius{chip=~\".*k10temp.*|.*thermal_zone.*|.*asus_ec.*\", sensor=\"temp1\"}";
          legendFormat = "Tctl";
          refId = "A";
        }
      ];
    }
    {
      type = "gauge";
      title = "Memory Usage";
      gridPos = {
        h = 8;
        w = 4;
        x = 12;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "yellow";
            value = 60;
          }
          {
            color = "orange";
            value = 80;
          }
          {
            color = "red";
            value = 90;
          }
        ];
        unit = "percent";
        min = 0;
        max = 100;
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
      };
      targets = [
        {
          expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Memory Used";
      gridPos = {
        h = 8;
        w = 4;
        x = 16;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "bytes";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes";
          legendFormat = "Used";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Load Average (1m)";
      gridPos = {
        h = 8;
        w = 4;
        x = 20;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "yellow";
            value = 8;
          }
          {
            color = "orange";
            value = 16;
          }
          {
            color = "red";
            value = 24;
          }
        ];
        decimals = 2;
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "node_load1";
          refId = "A";
        }
      ];
    }
    # Row 2: CPU Usage and Power Over Time
    {
      type = "timeseries";
      title = "CPU Usage Over Time";
      gridPos = {
        h = 8;
        w = 8;
        x = 0;
        y = 8;
      };

      fieldConfig.defaults = {
        unit = "percent";
        min = 0;
        max = 100;
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
          legendFormat = "Total";
          refId = "A";
        }
        {
          expr = "avg(irate(node_cpu_seconds_total{mode=\"user\"}[5m])) * 100";
          legendFormat = "User";
          refId = "B";
        }
        {
          expr = "avg(irate(node_cpu_seconds_total{mode=\"system\"}[5m])) * 100";
          legendFormat = "System";
          refId = "C";
        }
        {
          expr = "avg(irate(node_cpu_seconds_total{mode=\"iowait\"}[5m])) * 100";
          legendFormat = "IOWait";
          refId = "D";
        }
      ];
    }
    {
      type = "timeseries";
      title = "CPU Power Over Time";
      gridPos = {
        h = 8;
        w = 8;
        x = 8;
        y = 8;
      };

      fieldConfig.defaults = {
        unit = "watt";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "rate(node_hwmon_energy_joule_total{chip=\"platform_zenergy_0\", sensor=\"energy17\"}[5m])";
          legendFormat = "Package Power";
          refId = "A";
        }
        {
          expr = "sum(rate(node_hwmon_energy_joule_total{chip=\"platform_zenergy_0\", sensor!=\"energy17\"}[5m]))";
          legendFormat = "Core Power";
          refId = "B";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Cumulative Energy (kWh)";
      gridPos = {
        h = 8;
        w = 8;
        x = 16;
        y = 8;
      };

      fieldConfig.defaults = {
        unit = "kWh";
      };
      options = {
        legend = {
          displayMode = "table";
          placement = "bottom";
          calcs = [ "diff" ];
        };
      };
      targets = [
        {
          expr = "node_hwmon_energy_joule_total{chip=\"platform_zenergy_0\", sensor=\"energy17\"} / 3600000";
          legendFormat = "Total Energy";
          refId = "A";
        }
      ];
    }

    # Row 3: Temperature and Frequency
    {
      type = "timeseries";
      title = "CPU Temperature Over Time";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 16;
      };

      fieldConfig.defaults = {
        unit = "celsius";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "node_hwmon_temp_celsius{chip=~\".*k10temp.*|.*thermal_zone.*|.*asus_ec.*\", sensor=\"temp1\"}";
          legendFormat = "Tctl";
          refId = "A";
        }
        {
          expr = "node_hwmon_temp_celsius{chip=~\".*k10temp.*|.*thermal_zone.*|.*asus_ec.*\", sensor=\"temp3\"}";
          legendFormat = "Tccd1";
          refId = "B";
        }
        {
          expr = "node_hwmon_temp_celsius{chip=~\".*k10temp.*|.*thermal_zone.*|.*asus_ec.*\", sensor=\"temp4\"}";
          legendFormat = "Tccd2";
          refId = "C";
        }
      ];
    }
    {
      type = "timeseries";
      title = "CPU Frequency";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 16;
      };

      fieldConfig.defaults = {
        unit = "hertz";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "avg(node_cpu_scaling_frequency_hertz)";
          legendFormat = "Average";
          refId = "A";
        }
        {
          expr = "max(node_cpu_scaling_frequency_hertz)";
          legendFormat = "Max";
          refId = "B";
        }
        {
          expr = "min(node_cpu_scaling_frequency_hertz)";
          legendFormat = "Min";
          refId = "C";
        }
      ];
    }
    # Row 4: Memory
    {
      type = "timeseries";
      title = "Memory Usage Over Time";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 24;
      };

      fieldConfig.defaults = {
        unit = "bytes";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes";
          legendFormat = "Used";
          refId = "A";
        }
        {
          expr = "node_memory_Cached_bytes";
          legendFormat = "Cached";
          refId = "B";
        }
        {
          expr = "node_memory_Buffers_bytes";
          legendFormat = "Buffers";
          refId = "C";
        }
        {
          expr = "node_memory_MemFree_bytes";
          legendFormat = "Free";
          refId = "D";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Swap Usage";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 24;
      };

      fieldConfig.defaults = {
        unit = "bytes";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes";
          legendFormat = "Swap Used";
          refId = "A";
        }
        {
          expr = "node_memory_SwapTotal_bytes";
          legendFormat = "Swap Total";
          refId = "B";
        }
      ];
    }
    # Row 5: Disk I/O
    {
      type = "timeseries";
      title = "Disk I/O Throughput";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 32;
      };

      fieldConfig.defaults = {
        unit = "Bps";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "sum(irate(node_disk_read_bytes_total{device=~\"nvme.*|sd.*\"}[5m]))";
          legendFormat = "Read";
          refId = "A";
        }
        {
          expr = "sum(irate(node_disk_written_bytes_total{device=~\"nvme.*|sd.*\"}[5m]))";
          legendFormat = "Write";
          refId = "B";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Disk I/O Operations";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 32;
      };

      fieldConfig.defaults = {
        unit = "iops";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "sum(irate(node_disk_reads_completed_total{device=~\"nvme.*|sd.*\"}[5m]))";
          legendFormat = "Reads";
          refId = "A";
        }
        {
          expr = "sum(irate(node_disk_writes_completed_total{device=~\"nvme.*|sd.*\"}[5m]))";
          legendFormat = "Writes";
          refId = "B";
        }
      ];
    }
    # Row 6: NVMe Temperatures
    {
      type = "timeseries";
      title = "NVMe Temperatures";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 40;
      };

      fieldConfig.defaults = {
        unit = "celsius";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "node_hwmon_temp_celsius{chip=~\"nvme.*\"}";
          legendFormat = "{{chip}}";
          refId = "A";
        }
      ];
    }
    # Row 7: Network
    {
      type = "timeseries";
      title = "Network Traffic";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 48;
      };

      fieldConfig.defaults = {
        unit = "bps";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "sum(irate(node_network_receive_bytes_total{device!~\"lo|veth.*|br.*|docker.*\"}[5m])) * 8";
          legendFormat = "Receive";
          refId = "A";
        }
        {
          expr = "sum(irate(node_network_transmit_bytes_total{device!~\"lo|veth.*|br.*|docker.*\"}[5m])) * 8";
          legendFormat = "Transmit";
          refId = "B";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Network Errors & Drops";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 48;
      };

      fieldConfig.defaults = {
        unit = "pps";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "sum(irate(node_network_receive_drop_total{device!~\"lo|veth.*\"}[5m]))";
          legendFormat = "RX Drops";
          refId = "A";
        }
        {
          expr = "sum(irate(node_network_transmit_drop_total{device!~\"lo|veth.*\"}[5m]))";
          legendFormat = "TX Drops";
          refId = "B";
        }
        {
          expr = "sum(irate(node_network_receive_errs_total{device!~\"lo|veth.*\"}[5m]))";
          legendFormat = "RX Errors";
          refId = "C";
        }
        {
          expr = "sum(irate(node_network_transmit_errs_total{device!~\"lo|veth.*\"}[5m]))";
          legendFormat = "TX Errors";
          refId = "D";
        }
      ];
    }
    # Row 8: Filesystem
    {
      type = "bargauge";
      title = "Filesystem Usage";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 56;
      };

      fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "percentage";
        thresholds.steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "yellow";
            value = 70;
          }
          {
            color = "orange";
            value = 85;
          }
          {
            color = "red";
            value = 95;
          }
        ];
        unit = "percent";
        min = 0;
        max = 100;
      };
      options = {
        displayMode = "lcd";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
      };
      targets = [
        {
          expr = "(1 - (node_filesystem_avail_bytes{fstype=~\"ext4|xfs|btrfs|zfs\",mountpoint!~\"/boot.*\"} / node_filesystem_size_bytes{fstype=~\"ext4|xfs|btrfs|zfs\",mountpoint!~\"/boot.*\"})) * 100";
          legendFormat = "{{mountpoint}}";
          refId = "A";
        }
      ];
    }
    # Row 9: System Pressure (PSI)
    {
      type = "timeseries";
      title = "CPU Pressure";
      gridPos = {
        h = 6;
        w = 8;
        x = 0;
        y = 64;
      };

      fieldConfig.defaults = {
        unit = "percent";
        min = 0;
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "irate(node_pressure_cpu_waiting_seconds_total[5m]) * 100";
          legendFormat = "Wait";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Memory Pressure";
      gridPos = {
        h = 6;
        w = 8;
        x = 8;
        y = 64;
      };

      fieldConfig.defaults = {
        unit = "percent";
        min = 0;
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "irate(node_pressure_memory_waiting_seconds_total[5m]) * 100";
          legendFormat = "Wait";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "I/O Pressure";
      gridPos = {
        h = 6;
        w = 8;
        x = 16;
        y = 64;
      };

      fieldConfig.defaults = {
        unit = "percent";
        min = 0;
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "irate(node_pressure_io_waiting_seconds_total[5m]) * 100";
          legendFormat = "Wait";
          refId = "A";
        }
      ];
    }
    # Row 10: IronMain CI exact physical I/O and bounded cache state
    {
      type = "timeseries";
      title = "IronMain Exact Invocation Physical I/O";
      description = "Completed invocation bytes are shown only for a unique transient command cgroup.";
      gridPos = {
        h = 7;
        w = 8;
        x = 0;
        y = 70;
      };
      fieldConfig.defaults.unit = "bytes";
      options.legend = {
        displayMode = "list";
        placement = "bottom";
      };
      targets = [
        {
          expr = "ironmain_ci_invocation_physical_write_bytes";
          legendFormat = "slot {{slot}} {{role}} write";
          refId = "A";
        }
        {
          expr = "ironmain_ci_invocation_physical_read_bytes";
          legendFormat = "slot {{slot}} {{role}} read";
          refId = "B";
        }
      ];
    }
    {
      type = "stat";
      title = "IronMain Invocation I/O Availability";
      description = "Each isolated invocation is explicitly available or unavailable; missing counters are never zero.";
      gridPos = {
        h = 7;
        w = 4;
        x = 8;
        y = 70;
      };
      fieldConfig.defaults = {
        mappings = [
          {
            type = "value";
            options = {
              "0" = {
                text = "Unavailable";
                color = "red";
              };
              "1" = {
                text = "Available";
                color = "green";
              };
            };
          }
        ];
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "red";
              value = null;
            }
            {
              color = "green";
              value = 1;
            }
          ];
        };
      };
      options = {
        colorMode = "background";
        reduceOptions.calcs = [ "lastNotNull" ];
      };
      targets = [
        {
          expr = "ironmain_ci_invocation_io_available";
          legendFormat = "slot {{slot}} {{role}}";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "IronMain Fixed Role Footprint";
      gridPos = {
        h = 7;
        w = 6;
        x = 12;
        y = 70;
      };
      fieldConfig.defaults.unit = "bytes";
      options.legend = {
        displayMode = "table";
        placement = "bottom";
      };
      targets = [
        {
          expr = "ironmain_ci_role_bytes";
          legendFormat = "slot {{slot}} {{role}}";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "IronMain Slot and Role State";
      gridPos = {
        h = 7;
        w = 6;
        x = 18;
        y = 70;
      };
      fieldConfig.defaults.mappings = [
        {
          type = "value";
          options = {
            "0".text = "Idle / Not reusable";
            "1".text = "Leased / Reusable";
          };
        }
      ];
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [
        {
          expr = "ironmain_ci_slot_leased";
          legendFormat = "slot {{slot}} leased";
          refId = "A";
        }
        {
          expr = "ironmain_ci_role_reusable";
          legendFormat = "slot {{slot}} {{role}} reusable";
          refId = "B";
        }
      ];
    }
  ];
  refresh = "30s";
  schemaVersion = 39;
  tags = [
    "system"
    "node"
    "cpu"
    "memory"
    "disk"
    "network"
  ];
  templating.list = [ ];
  time = {
    from = "now-6h";
    to = "now";
  };
  timepicker = { };
  timezone = "browser";
  title = "System Overview";
  uid = "system-overview";
  version = 1;
}

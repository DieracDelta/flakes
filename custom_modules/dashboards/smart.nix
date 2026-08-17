# SMART Dashboard - Disk health monitoring via smartctl
let
  writeAggregatePanel =
    {
      title,
      description,
      x,
      expr,
      instant ? false,
    }:
    {
      type = "stat";
      inherit title description;
      gridPos = {
        h = 6;
        w = 6;
        inherit x;
        y = 42;
      };

      fieldConfig.defaults = {
        unit = "decbytes";
        color.mode = "palette-classic";
      };
      options = {
        reduceOptions.calcs = [ "lastNotNull" ];
        colorMode = "value";
        graphMode = if instant then "none" else "area";
        textMode = "auto";
      };
      targets = [
        {
          inherit expr instant;
          range = !instant;
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    };

  userIoTimeseriesPanel =
    {
      title,
      description,
      x,
      y ? 48,
      unit,
      expr,
      legendFormat ? "{{user}} · {{device}}",
    }:
    {
      type = "timeseries";
      inherit title description;
      gridPos = {
        h = 8;
        w = 12;
        inherit x y;
      };
      fieldConfig.defaults = {
        inherit unit;
        color.mode = "palette-classic";
        custom = {
          drawStyle = "line";
          fillOpacity = 12;
          lineInterpolation = "linear";
          lineWidth = 1;
          showPoints = "never";
          spanNulls = true;
        };
      };
      options = {
        legend = {
          displayMode = "table";
          placement = "bottom";
          calcs = [
            "lastNotNull"
            "mean"
          ];
        };
        tooltip.mode = "multi";
      };
      targets = [
        {
          inherit expr legendFormat;
          refId = "A";
        }
      ];
    };

  userIoSelectedRangePanel =
    {
      title,
      description,
      x,
      expr,
    }:
    {
      type = "stat";
      inherit title description;
      gridPos = {
        h = 8;
        w = 12;
        inherit x;
        y = 56;
      };
      fieldConfig.defaults = {
        unit = "decbytes";
        color.mode = "palette-classic";
      };
      options = {
        reduceOptions.calcs = [ "lastNotNull" ];
        colorMode = "value";
        graphMode = "none";
        textMode = "auto";
      };
      targets = [
        {
          inherit expr;
          instant = true;
          range = false;
          legendFormat = "{{user}} · {{device}}";
          refId = "A";
        }
      ];
    };
in
{
  annotations.list = [ ];
  editable = true;
  fiscalYearStartMonth = 0;
  graphTooltip = 0;
  links = [
    {
      title = "Current calendar month";
      tooltip = "Set exact calendar-month boundaries for the Selected Range panel";
      type = "link";
      url = "?from=now%2FM&to=now";
      includeVars = false;
      keepTime = false;
      targetBlank = false;
    }
    {
      title = "Previous calendar month";
      tooltip = "Show the previous complete calendar month";
      type = "link";
      url = "?from=now-1M%2FM&to=now%2FM";
      includeVars = false;
      keepTime = false;
      targetBlank = false;
    }
  ];
  panels = [
    # Row 1: Overview Stats
    {
      type = "stat";
      title = "Devices Monitored";
      gridPos = {
        h = 4;
        w = 4;
        x = 0;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "fixed";
        color.fixedColor = "blue";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "count(smartctl_device_smart_status)";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Healthy Devices";
      gridPos = {
        h = 4;
        w = 4;
        x = 4;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
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
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "background";
      };
      targets = [
        {
          expr = "sum(smartctl_device_smart_status)";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Unhealthy Devices";
      gridPos = {
        h = 4;
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
            color = "red";
            value = 1;
          }
        ];
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "background";
      };
      targets = [
        {
          expr = "count(smartctl_device_smart_status == 0) or vector(0)";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Total Power-On Time";
      description = "Combined power-on time across all devices";
      gridPos = {
        h = 4;
        w = 6;
        x = 12;
        y = 0;
      };

      fieldConfig.defaults = {
        unit = "s";
        color.mode = "fixed";
        color.fixedColor = "purple";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "sum(smartctl_device_power_on_seconds)";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Exporter Status";
      gridPos = {
        h = 4;
        w = 6;
        x = 18;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
          {
            color = "red";
            value = null;
          }
          {
            color = "green";
            value = 1;
          }
        ];
        mappings = [
          {
            type = "value";
            options = {
              "0" = {
                text = "Down";
              };
              "1" = {
                text = "Up";
              };
            };
          }
        ];
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "background";
      };
      targets = [
        {
          expr = "up{job=\"smartctl\"}";
          refId = "A";
        }
      ];
    }

    # Row 2: Device Table
    {
      type = "table";
      title = "Device Overview";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 4;
      };

      targets = [
        {
          expr = "smartctl_device{device!=\"\"}";
          refId = "A";
          format = "table";
          instant = true;
        }
      ];
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              Value = true;
              __name__ = true;
              instance = true;
              job = true;
            };
            renameByName = {
              device = "Device";
              model_family = "Family";
              model_name = "Model";
              serial_number = "Serial";
              form_factor = "Form Factor";
              device_type = "Type";
            };
            indexByName = {
              device = 0;
              model_name = 1;
              model_family = 2;
              serial_number = 3;
              form_factor = 4;
              device_type = 5;
            };
          };
        }
      ];
      fieldConfig.defaults = {
        custom.filterable = true;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
      };
    }

    # Row 3: Temperature
    {
      type = "gauge";
      title = "Disk Temperatures";
      gridPos = {
        h = 8;
        w = 8;
        x = 0;
        y = 12;
      };

      fieldConfig.defaults = {
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
          {
            color = "blue";
            value = null;
          }
          {
            color = "green";
            value = 25;
          }
          {
            color = "yellow";
            value = 40;
          }
          {
            color = "orange";
            value = 50;
          }
          {
            color = "red";
            value = 60;
          }
        ];
        unit = "celsius";
        min = 0;
        max = 80;
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        orientation = "horizontal";
        showThresholdLabels = false;
        showThresholdMarkers = true;
      };
      targets = [
        {
          expr = "smartctl_device_temperature{temperature_type=\"current\"}";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Temperature Over Time";
      gridPos = {
        h = 8;
        w = 16;
        x = 8;
        y = 12;
      };

      fieldConfig.defaults = {
        unit = "celsius";
        color.mode = "palette-classic";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
        tooltip.mode = "multi";
      };
      targets = [
        {
          expr = "smartctl_device_temperature{temperature_type=\"current\"}";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }

    # Row 4: Power & Wear
    {
      type = "bargauge";
      title = "Power-On Time";
      description = "Total operating hours per device";
      gridPos = {
        h = 8;
        w = 8;
        x = 0;
        y = 20;
      };

      fieldConfig.defaults = {
        unit = "s";
        color.mode = "palette-classic";
      };
      options = {
        displayMode = "gradient";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
      };
      targets = [
        {
          expr = "smartctl_device_power_on_seconds";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }
    {
      type = "bargauge";
      title = "Power Cycle Count";
      description = "Number of power on/off cycles";
      gridPos = {
        h = 8;
        w = 8;
        x = 8;
        y = 20;
      };

      fieldConfig.defaults = {
        unit = "short";
        color.mode = "palette-classic";
      };
      options = {
        displayMode = "gradient";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
      };
      targets = [
        {
          expr = "smartctl_device_power_cycle_count";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }
    {
      type = "bargauge";
      title = "Media/Data Integrity Errors";
      description = "NVMe media and data integrity errors (should be 0)";
      gridPos = {
        h = 8;
        w = 8;
        x = 16;
        y = 20;
      };

      fieldConfig.defaults = {
        unit = "short";
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
          {
            color = "green";
            value = null;
          }
          {
            color = "red";
            value = 1;
          }
        ];
        noValue = "N/A";
      };
      options = {
        displayMode = "gradient";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
      };
      targets = [
        {
          expr = "smartctl_device_media_errors";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }

    # Row 5: NVMe Specific
    {
      type = "timeseries";
      title = "NVMe Percentage Used";
      description = "Vendor-specific estimate of device life used (100 = end of life)";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 28;
      };

      fieldConfig.defaults = {
        unit = "percent";
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
            value = 80;
          }
          {
            color = "red";
            value = 90;
          }
        ];
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
          expr = "smartctl_device_percentage_used";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "NVMe Available Spare";
      description = "Remaining spare capacity for bad block replacement";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 28;
      };

      fieldConfig.defaults = {
        unit = "percent";
        color.mode = "thresholds";
        thresholds.mode = "absolute";
        thresholds.steps = [
          {
            color = "red";
            value = null;
          }
          {
            color = "orange";
            value = 10;
          }
          {
            color = "yellow";
            value = 25;
          }
          {
            color = "green";
            value = 50;
          }
        ];
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
          expr = "smartctl_device_available_spare";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }

    # Row 6: Data Written/Read
    {
      type = "stat";
      title = "Total Data Written";
      gridPos = {
        h = 6;
        w = 12;
        x = 0;
        y = 36;
      };

      fieldConfig.defaults = {
        unit = "decbytes";
        color.mode = "palette-classic";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
        graphMode = "area";
        textMode = "auto";
      };
      targets = [
        {
          expr = "smartctl_device_bytes_written";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Total Data Read";
      gridPos = {
        h = 6;
        w = 12;
        x = 12;
        y = 36;
      };

      fieldConfig.defaults = {
        unit = "decbytes";
        color.mode = "palette-classic";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
        graphMode = "area";
        textMode = "auto";
      };
      targets = [
        {
          expr = "smartctl_device_bytes_read";
          legendFormat = "{{device}}";
          refId = "A";
        }
      ];
    }

    # Row 7: Retained write aggregates
    (writeAggregatePanel {
      title = "Written — Last 24 Hours";
      description = "Rolling 24-hour physical writes from the kernel's whole-device counters";
      x = 0;
      expr = "node_disk_written_bytes_1d";
    })
    (writeAggregatePanel {
      title = "Written — Last 7 Days";
      description = "Rolling seven-day physical writes from the kernel's whole-device counters";
      x = 6;
      expr = "node_disk_written_bytes_7d";
    })
    (writeAggregatePanel {
      title = "Written — Last 30 Days";
      description = "Rolling 30-day physical writes; use Selected Range for calendar months";
      x = 12;
      expr = "node_disk_written_bytes_30d";
    })
    (writeAggregatePanel {
      title = "Written — Selected Range";
      description = "Exact increase over the dashboard range; use the calendar-month links above";
      x = 18;
      expr = ''increase(node_disk_written_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])'';
      instant = true;
    })

    # Row 8: Cgroup-attributed and residual physical disk I/O. Filesystem
    # metadata and kernel writeback are not always charged to a child cgroup,
    # so expose the whole-device remainder instead of silently dropping it.
    (userIoTimeseriesPanel {
      title = "Physical Write Attribution by Drive";
      description = "Five-minute physical write throughput. Named users and system are cgroup-attributed; unattributed is the nonnegative remainder of the whole-device counter and includes filesystem metadata and kernel writeback.";
      x = 0;
      unit = "Bps";
      expr = ''
        sum by (user, device) (
          user_cgroup_io_write_bytes_per_second{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}
        )
        or label_replace(
          node_disk_unattributed_write_bytes_per_second,
          "user", "unattributed", "", ""
        )
      '';
    })
    (userIoTimeseriesPanel {
      title = "Physical Read Attribution by Drive";
      description = "Five-minute physical read throughput. Named users and system are cgroup-attributed; unattributed is the nonnegative remainder of the whole-device counter.";
      x = 12;
      unit = "Bps";
      expr = ''
        sum by (user, device) (
          user_cgroup_io_read_bytes_per_second{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}
        )
        or label_replace(
          node_disk_unattributed_read_bytes_per_second,
          "user", "unattributed", "", ""
        )
      '';
    })

    # Row 9: Selected-range totals with the same explicit residual.
    (userIoSelectedRangePanel {
      title = "Physical Writes by Source — Selected Range";
      description = "Cgroup-attributed writes plus the whole-device remainder. The series sum to the kernel physical-write counter for each drive.";
      x = 0;
      expr = ''
        sum by (user, device) (
          increase(user_cgroup_io_write_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])
        )
        or label_replace(
          clamp_min(
            increase(node_disk_written_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])
              - on (device) (
                sum by (device) (
                  increase(user_cgroup_io_write_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])
                )
                or sum by (device) (
                  increase(node_disk_written_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])
                ) * 0
              ),
            0
          ),
          "user", "unattributed", "", ""
        )
      '';
    })
    (userIoSelectedRangePanel {
      title = "Physical Reads by Source — Selected Range";
      description = "Cgroup-attributed reads plus the whole-device remainder. The series sum to the kernel physical-read counter for each drive.";
      x = 12;
      expr = ''
        sum by (user, device) (
          increase(user_cgroup_io_read_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])
        )
        or label_replace(
          clamp_min(
            increase(node_disk_read_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])
              - on (device) (
                sum by (device) (
                  increase(user_cgroup_io_read_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])
                )
                or sum by (device) (
                  increase(node_disk_read_bytes_total{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}[$__range])
                ) * 0
              ),
            0
          ),
          "user", "unattributed", "", ""
        )
      '';
    })

    # Row 10: Per-service I/O. Service cgroups are descendants of system.slice,
    # so these panels diagnose the system aggregate and are never added to it.
    (userIoTimeseriesPanel {
      title = "System Service Write Throughput";
      description = "Top systemd services by cgroup-charged physical writes. Filesystem metadata and kernel writeback remain in the unattributed series above.";
      x = 0;
      y = 64;
      unit = "Bps";
      expr = ''
        topk(15,
          sum by (unit, device) (
            systemd_service_cgroup_io_write_bytes_per_second{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}
          )
        )
      '';
      legendFormat = "{{unit}} · {{device}}";
    })
    (userIoTimeseriesPanel {
      title = "System Service Read Throughput";
      description = "Top systemd services by cgroup-charged physical reads.";
      x = 12;
      y = 64;
      unit = "Bps";
      expr = ''
        topk(15,
          sum by (unit, device) (
            systemd_service_cgroup_io_read_bytes_per_second{device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"}
          )
        )
      '';
      legendFormat = "{{unit}} · {{device}}";
    })

    # Row 11: SMART Attributes (for SATA drives)
    {
      type = "table";
      title = "SMART Attributes";
      description = "Raw SMART attribute values for all devices";
      gridPos = {
        h = 10;
        w = 24;
        x = 0;
        y = 72;
      };

      targets = [
        {
          expr = "smartctl_device_attribute{attribute_value_type=\"raw\"}";
          refId = "A";
          format = "table";
          instant = true;
        }
      ];
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              __name__ = true;
              instance = true;
              job = true;
              attribute_value_type = true;
            };
            renameByName = {
              device = "Device";
              attribute_name = "Attribute";
              attribute_id = "ID";
              Value = "Raw Value";
            };
            indexByName = {
              device = 0;
              attribute_id = 1;
              attribute_name = 2;
              Value = 3;
            };
          };
        }
        {
          id = "sortBy";
          options = {
            fields = { };
            sort = [
              { field = "Device"; }
              { field = "ID"; }
            ];
          };
        }
      ];
      fieldConfig.defaults = {
        custom.filterable = true;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
      };
    }
  ];
  refresh = "1m";
  schemaVersion = 39;
  tags = [
    "smart"
    "storage"
    "disk"
  ];
  templating.list = [ ];
  time = {
    from = "now-24h";
    to = "now";
  };
  timepicker = { };
  timezone = "America/New_York";
  title = "Disk SMART Health";
  uid = "disk-smart-health";
  version = 1;
}

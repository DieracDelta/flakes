# Systemd Dashboard - Service monitoring
{
  annotations.list = [ ];
  editable = true;
  fiscalYearStartMonth = 0;
  graphTooltip = 0;
  links = [ ];
  panels = [
    # Row 1: Overview Stats
    {
      type = "stat";
      title = "Active Units";
      gridPos = {
        h = 6;
        w = 6;
        x = 0;
        y = 0;
      };

      fieldConfig.defaults = {
        color = {
          mode = "fixed";
          fixedColor = "green";
        };
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "sum(systemd_unit_state{state=\"active\"})";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Failed Units";
      gridPos = {
        h = 6;
        w = 6;
        x = 6;
        y = 0;
      };

      fieldConfig.defaults = {
        color = {
          mode = "thresholds";
        };
        thresholds = {
          mode = "absolute";
          steps = [
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
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "background";
      };
      targets = [
        {
          expr = "sum(systemd_unit_state{state=\"failed\"})";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Unit Restarts (Last 1h)";
      gridPos = {
        h = 6;
        w = 6;
        x = 12;
        y = 0;
      };

      fieldConfig.defaults = {
        unit = "short";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "sum(increase(systemd_service_restart_total[1h])) or vector(0)";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Total Units";
      description = "Total number of systemd units (services, mounts, targets, timers, etc.)";
      gridPos = {
        h = 6;
        w = 6;
        x = 18;
        y = 0;
      };

      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "count(count by (name) (systemd_unit_state))";
          refId = "A";
        }
      ];
    }
    # Row 2: Failed Units List
    {
      type = "stat";
      title = "Failed Units (Current)";
      description = "List of currently failed systemd units. Empty when all units are healthy.";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 6;
      };

      targets = [
        {
          expr = "systemd_unit_state{state=\"failed\"} == 1";
          legendFormat = "{{name}}";
          refId = "A";
        }
      ];
      fieldConfig.defaults = {
        color = {
          mode = "fixed";
          fixedColor = "red";
        };
        noValue = "None - All units healthy";
      };
      options = {
        reduceOptions = {
          values = true;
          calcs = [ ];
          fields = "/^name$/";
        };
        colorMode = "background";
        textMode = "name";
        justifyMode = "auto";
        graphMode = "none";
      };
    }
    # Row 3: Restart Loops
    {
      type = "bargauge";
      title = "Top Restarts (Last 1h)";
      description = "Units restarting frequently indicating crash loops. Shows top 10 services by restart count.";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 6;
      };

      fieldConfig.defaults = {
        unit = "short";
        min = 0;
        noValue = "No restarts";
      };
      options = {
        displayMode = "gradient";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        minVizHeight = 10;
        minVizWidth = 0;
      };
      targets = [
        {
          expr = "topk(10, increase(systemd_service_restart_total[1h]))";
          legendFormat = "{{name}}";
          refId = "A";
          instant = true;
        }
      ];
    }
    # Row 4: Activation Activity
    {
      type = "timeseries";
      title = "Unit State Transitions";
      description = "Number of units transitioning into active or inactive states over time";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 14;
      };

      fieldConfig.defaults = {
        unit = "short";
      };
      targets = [
        {
          expr = "sum(changes(systemd_unit_active_enter_time_seconds[5m]))";
          legendFormat = "Activations";
          refId = "A";
        }
        {
          expr = "sum(changes(systemd_unit_inactive_enter_time_seconds[5m]))";
          legendFormat = "Deactivations";
          refId = "B";
        }
      ];
    }
  ];
  refresh = "30s";
  schemaVersion = 39;
  tags = [ "systemd" ];
  templating.list = [ ];
  time = {
    from = "now-1h";
    to = "now";
  };
  timepicker = { };
  timezone = "browser";
  title = "Systemd Services";
  uid = "systemd-services";
  version = 1;
}

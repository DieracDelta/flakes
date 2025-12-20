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
          expr = "sum(increase(systemd_unit_restarts_total[1h]))";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Total Units";
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
          expr = "sum(systemd_unit_info)";
          refId = "A";
        }
      ];
    }
    # Row 2: Failed Units List
    {
      type = "table";
      title = "Failed Units (Current)";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 6;
      };

      targets = [
        {
          expr = "systemd_unit_state{state=\"failed\"} > 0";
          legendFormat = "{{name}}";
          refId = "A";
        }
      ];
      fieldConfig.defaults = {
        custom = {
          filterable = true;
        };
      };
    }
    # Row 3: Restart Loops
    {
      type = "bargauge";
      title = "Top Restarts (Last 1h)";
      description = "Units restarting frequently indicating crash loops.";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 6;
      };

      fieldConfig.defaults = {
        unit = "short";
      };
      options = {
        displayMode = "gradient";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "max" ];
        };
      };
      targets = [
        {
          expr = "topk(10, increase(systemd_unit_restarts_total[1h]) > 0)";
          legendFormat = "{{name}}";
          refId = "A";
        }
      ];
    }
    # Row 4: Activation Activity
    {
      type = "timeseries";
      title = "Unit Activation/Deactivation Rate";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 14;
      };

      targets = [
        {
          expr = "rate(systemd_unit_state{state=\"activating\"}[5m])";
          legendFormat = "Activating";
          refId = "A";
        }
        {
          expr = "rate(systemd_unit_state{state=\"deactivating\"}[5m])";
          legendFormat = "Deactivating";
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

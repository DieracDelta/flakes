# UPS Dashboard - Eaton 5SC UPS monitoring via NUT
{
  annotations.list = [ ];
  editable = true;
  fiscalYearStartMonth = 0;
  graphTooltip = 0;
  links = [ ];
  panels = [
    # Row 0: Power Status Timeline
    {
      type = "state-timeline";
      title = "Power Outage History";
      description = "Shows when the UPS was on battery power (power outage) vs online (AC power)";

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
        mappings = [
          {
            type = "value";
            options."0" = {
              text = "Online (AC)";
              color = "green";
            };
          }
          {
            type = "value";
            options."1" = {
              text = "On Battery";
              color = "red";
            };
          }
        ];
        custom.fillOpacity = 80;
      };
      options = {
        showValue = "auto";
        alignValue = "center";
        mergeValues = true;
        rowHeight = 0.9;
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = ''network_ups_tools_ups_status{flag="OB"}'';
          legendFormat = "Power Status";
          refId = "A";
        }
      ];
    }
    # Row 1: Status gauges
    {
      type = "gauge";
      title = "Battery Charge";
      gridPos = {
        h = 8;
        w = 6;
        x = 0;
        y = 6;
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
            color = "orange";
            value = 30;
          }
          {
            color = "yellow";
            value = 50;
          }
          {
            color = "green";
            value = 80;
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
          expr = "network_ups_tools_battery_charge";
          refId = "A";
        }
      ];
    }
    {
      type = "gauge";
      title = "UPS Load";
      gridPos = {
        h = 8;
        w = 6;
        x = 6;
        y = 6;
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
          expr = "network_ups_tools_ups_load";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Runtime Remaining";
      gridPos = {
        h = 8;
        w = 6;
        x = 12;
        y = 6;
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
            color = "orange";
            value = 300;
          }
          {
            color = "yellow";
            value = 600;
          }
          {
            color = "green";
            value = 1200;
          }
        ];
        unit = "s";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "network_ups_tools_battery_runtime";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Power Draw";
      gridPos = {
        h = 8;
        w = 6;
        x = 18;
        y = 6;
      };

      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "watt";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "network_ups_tools_ups_realpower";
          legendFormat = "Real Power";
          refId = "A";
        }
      ];
    }
    # Row 2: Voltage and current graphs
    {
      type = "timeseries";
      title = "Input/Output Voltage";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 14;
      };

      fieldConfig.defaults = {
        unit = "volt";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "network_ups_tools_input_voltage";
          legendFormat = "Input";
          refId = "A";
        }
        {
          expr = "network_ups_tools_output_voltage";
          legendFormat = "Output";
          refId = "B";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Battery Voltage";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 14;
      };

      fieldConfig.defaults = {
        unit = "volt";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "network_ups_tools_battery_voltage";
          legendFormat = "Battery";
          refId = "A";
        }
        {
          expr = "network_ups_tools_battery_voltage_nominal";
          legendFormat = "Nominal";
          refId = "B";
        }
      ];
    }
    # Row 3: Load and runtime over time
    {
      type = "timeseries";
      title = "UPS Load Over Time";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 22;
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
          expr = "network_ups_tools_ups_load";
          legendFormat = "Load %";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Power Consumption";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 22;
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
          expr = "network_ups_tools_ups_realpower";
          legendFormat = "Real Power (W)";
          refId = "A";
        }
        {
          expr = "network_ups_tools_ups_power";
          legendFormat = "Apparent Power (VA)";
          refId = "B";
        }
      ];
    }
    # Row 4: Battery and efficiency
    {
      type = "timeseries";
      title = "Battery Charge Over Time";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 30;
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
          expr = "network_ups_tools_battery_charge";
          legendFormat = "Charge %";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "UPS Efficiency";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 30;
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
          expr = "network_ups_tools_ups_efficiency";
          legendFormat = "Efficiency %";
          refId = "A";
        }
      ];
    }
    # Row 5: Frequency
    {
      type = "timeseries";
      title = "Input/Output Frequency";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 38;
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
          expr = "network_ups_tools_input_frequency";
          legendFormat = "Input";
          refId = "A";
        }
        {
          expr = "network_ups_tools_output_frequency";
          legendFormat = "Output";
          refId = "B";
        }
      ];
    }
    {
      type = "stat";
      title = "Total UPS Energy";
      description = "Total UPS energy consumed over time range";
      datasource = {
        type = "prometheus";
        uid = "PBFA97CFB590B2093";
      };
      gridPos = {
        h = 8;
        w = 6;
        x = 18;
        y = 6;
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
          expr = "network_ups_tools_ups_realpower*$__interval_ms/(1000*3.6E6)";
          instant = false;
          legendFormat = "Total";
          range = true;
          refId = "A";
        }
      ];
    }
  ];
  refresh = "30s";
  schemaVersion = 39;
  tags = [
    "ups"
    "nut"
    "eaton"
  ];
  templating.list = [ ];
  time = {
    from = "now-6h";
    to = "now";
  };
  timepicker = { };
  timezone = "browser";
  title = "Eaton 5SC UPS";
  uid = "eaton-5sc-ups";
  version = 1;
}

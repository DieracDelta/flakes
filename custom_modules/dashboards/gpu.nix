# GPU Dashboard - NVIDIA RTX 4090 monitoring via DCGM
{
  annotations.list = [ ];
  editable = true;
  fiscalYearStartMonth = 0;
  graphTooltip = 0;
  links = [ ];
  panels = [
    # Row 1: Status gauges
    {
      type = "gauge";
      title = "GPU Temperature";
      gridPos = {
        h = 8;
        w = 5;
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
          expr = "DCGM_FI_DEV_GPU_TEMP";
          refId = "A";
        }
      ];
    }
    {
      type = "gauge";
      title = "GPU Utilization";
      gridPos = {
        h = 8;
        w = 5;
        x = 5;
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
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
      };
      targets = [
        {
          expr = "DCGM_FI_DEV_GPU_UTIL";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Power Draw";
      gridPos = {
        h = 8;
        w = 5;
        x = 10;
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
            value = 200;
          }
          {
            color = "orange";
            value = 350;
          }
          {
            color = "red";
            value = 400;
          }
        ];
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
          expr = "DCGM_FI_DEV_POWER_USAGE";
          legendFormat = "Power";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Total Energy";
      description = "Total energy consumed by GPU over time range";
      datasource = {
        type = "prometheus";
        uid = "PBFA97CFB590B2093";
      };
      gridPos = {
        h = 8;
        w = 5;
        x = 15;
        y = 0;
      };

      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "kwatth";
        decimals = 2;
        mappings = [ ];
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
      fieldConfig.overrides = [ ];
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
          expr = "DCGM_FI_DEV_POWER_USAGE*$__interval_ms/(1000*3.6E6)";
          instant = false;
          legendFormat = "Total";
          range = true;
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "VRAM Used";
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
            value = 16000;
          }
          {
            color = "orange";
            value = 20000;
          }
          {
            color = "red";
            value = 23000;
          }
        ];
        unit = "decmbytes";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "DCGM_FI_DEV_FB_USED";
          legendFormat = "Used";
          refId = "A";
        }
      ];
    }
    # Row 2: Utilization over time
    {
      type = "timeseries";
      title = "GPU Utilization Over Time";
      gridPos = {
        h = 8;
        w = 12;
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
          expr = "DCGM_FI_DEV_GPU_UTIL";
          legendFormat = "GPU Core";
          refId = "A";
        }
        {
          expr = "DCGM_FI_DEV_MEM_COPY_UTIL";
          legendFormat = "Memory Copy";
          refId = "B";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Encoder/Decoder Utilization";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
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
          expr = "DCGM_FI_DEV_ENC_UTIL";
          legendFormat = "Encoder (NVENC)";
          refId = "A";
        }
        {
          expr = "DCGM_FI_DEV_DEC_UTIL";
          legendFormat = "Decoder (NVDEC)";
          refId = "B";
        }
      ];
    }
    # Row 3: Temperature and Power
    {
      type = "timeseries";
      title = "Temperature Over Time";
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
          expr = "DCGM_FI_DEV_GPU_TEMP";
          legendFormat = "GPU";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Power Consumption Over Time";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 16;
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
          expr = "DCGM_FI_DEV_POWER_USAGE";
          legendFormat = "Power Draw";
          refId = "A";
        }
      ];
    }
    # Row 4: Memory
    {
      type = "timeseries";
      title = "VRAM Usage Over Time";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 24;
      };

      fieldConfig.defaults = {
        unit = "decmbytes";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "DCGM_FI_DEV_FB_USED";
          legendFormat = "Used";
          refId = "A";
        }
        {
          expr = "DCGM_FI_DEV_FB_FREE";
          legendFormat = "Free";
          refId = "B";
        }
        {
          expr = "DCGM_FI_DEV_FB_RESERVED";
          legendFormat = "Reserved";
          refId = "C";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Clock Speeds";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 24;
      };

      fieldConfig.defaults = {
        unit = "clockmhz";
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
      };
      targets = [
        {
          expr = "DCGM_FI_DEV_SM_CLOCK";
          legendFormat = "SM Clock";
          refId = "A";
        }
        {
          expr = "DCGM_FI_DEV_MEM_CLOCK";
          legendFormat = "Memory Clock";
          refId = "B";
        }
      ];
    }
    # Row 5: Energy consumption (counter)
    {
      type = "timeseries";
      title = "Energy Consumption Rate";
      description = "Rate of energy consumption (derivative of total energy counter)";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 32;
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
          expr = "rate(DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION[5m]) / 1000";
          legendFormat = "Energy Rate (W)";
          refId = "A";
        }
      ];
    }
    # Row 6: PCIe and Errors
    {
      type = "stat";
      title = "PCIe Replay Errors";
      gridPos = {
        h = 4;
        w = 6;
        x = 0;
        y = 40;
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
            value = 1;
          }
          {
            color = "red";
            value = 100;
          }
        ];
        unit = "none";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "DCGM_FI_DEV_PCIE_REPLAY_COUNTER";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "XID Errors";
      gridPos = {
        h = 4;
        w = 6;
        x = 6;
        y = 40;
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
        unit = "none";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "DCGM_FI_DEV_XID_ERRORS";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Uncorrectable Row Remaps";
      gridPos = {
        h = 4;
        w = 6;
        x = 12;
        y = 40;
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
            value = 1;
          }
          {
            color = "red";
            value = 5;
          }
        ];
        unit = "none";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "DCGM_FI_DEV_UNCORRECTABLE_REMAPPED_ROWS";
          refId = "A";
        }
      ];
    }
    {
      type = "stat";
      title = "Correctable Row Remaps";
      gridPos = {
        h = 4;
        w = 6;
        x = 18;
        y = 40;
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
            value = 1;
          }
          {
            color = "orange";
            value = 10;
          }
        ];
        unit = "none";
      };
      options = {
        reduceOptions = {
          calcs = [ "lastNotNull" ];
        };
        colorMode = "value";
      };
      targets = [
        {
          expr = "DCGM_FI_DEV_CORRECTABLE_REMAPPED_ROWS";
          refId = "A";
        }
      ];
    }
  ];
  refresh = "30s";
  schemaVersion = 39;
  tags = [
    "gpu"
    "nvidia"
    "dcgm"
    "rtx4090"
  ];
  templating.list = [ ];
  time = {
    from = "now-6h";
    to = "now";
  };
  timepicker = { };
  timezone = "browser";
  title = "NVIDIA RTX 4090";
  uid = "nvidia-rtx-4090";
  version = 1;
}

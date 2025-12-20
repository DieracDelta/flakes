# Network Dashboard - Traffic breakdown by process and systemd service
{
  annotations.list = [ ];
  editable = true;
  fiscalYearStartMonth = 0;
  graphTooltip = 0;
  links = [ ];
  panels = [
    # Row 1: Systemd Services
    {
      type = "timeseries";
      title = "Top Systemd Services (Download)";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 0;
      };

      fieldConfig.defaults = {
        unit = "Bps";
      };
      options = {
        legend = {
          displayMode = "table";
          placement = "right";
          calcs = [
            "mean"
            "max"
            "last"
          ];
        };
      };
      targets = [
        {
          expr = "topk(10, irate(systemd_unit_ingress_bytes[5m]))";
          legendFormat = "{{unit}}";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Top Systemd Services (Upload)";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 0;
      };

      fieldConfig.defaults = {
        unit = "Bps";
      };
      options = {
        legend = {
          displayMode = "table";
          placement = "right";
          calcs = [
            "mean"
            "max"
            "last"
          ];
        };
      };
      targets = [
        {
          expr = "topk(10, irate(systemd_unit_egress_bytes[5m]))";
          legendFormat = "{{unit}}";
          refId = "A";
        }
      ];
    }
    # Row 2: Nethogs Processes
    {
      type = "timeseries";
      title = "Top Processes (Download)";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 10;
      };

      fieldConfig.defaults = {
        unit = "Bps";
      };
      options = {
        legend = {
          displayMode = "table";
          placement = "right";
          calcs = [
            "mean"
            "max"
            "last"
          ];
        };
      };
      targets = [
        {
          expr = "topk(10, rate(nethogs_process_download_bytes{user!=\"\"}[5m]))";
          legendFormat = "{{process}} ({{user}})";
          refId = "A";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Top Processes (Upload)";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 10;
      };

      fieldConfig.defaults = {
        unit = "Bps";
      };
      options = {
        legend = {
          displayMode = "table";
          placement = "right";
          calcs = [
            "mean"
            "max"
            "last"
          ];
        };
      };
      targets = [
        {
          expr = "topk(10, rate(nethogs_process_upload_bytes{user!=\"\"}[5m]))";
          legendFormat = "{{process}} ({{user}})";
          refId = "A";
        }
      ];
    }
    # Row 3: Cumulative Usage
    {
      type = "timeseries";
      title = "Total System Data Usage (Cumulative)";
      gridPos = {
        h = 10;
        w = 8;
        x = 0;
        y = 20;
      };

      fieldConfig.defaults = {
        unit = "decbytes";
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
          expr = "sum(node_network_receive_bytes_total{device!~\"lo|veth.*|br.*|docker.*\"})";
          legendFormat = "Total Download";
          refId = "A";
        }
        {
          expr = "sum(node_network_transmit_bytes_total{device!~\"lo|veth.*|br.*|docker.*\"})";
          legendFormat = "Total Upload";
          refId = "B";
        }
      ];
    }
    {
      type = "bargauge";
      title = "Top Processes by Data Usage (In Selected Range)";
      description = "Shows the total data (Download + Upload) used by the top processes within the currently selected time window.";
      gridPos = {
        h = 10;
        w = 8;
        x = 8;
        y = 20;
      };

      fieldConfig.defaults = {
        unit = "decbytes";
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
      gridPos = {
        h = 10;
        w = 8;
        x = 16;
        y = 20;
      };

      fieldConfig.defaults = {
        unit = "decbytes";
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
  tags = [
    "network"
    "systemd"
    "nethogs"
  ];
  templating.list = [ ];
  time = {
    from = "now-1h";
    to = "now";
  };
  timepicker = { };
  timezone = "browser";
  title = "Network Traffic Breakdown";
  uid = "network-breakdown";
  version = 1;
}

# Unbound DNS Dashboard
{
  annotations.list = [ ];
  editable = true;
  fiscalYearStartMonth = 0;
  graphTooltip = 1;
  links = [ ];
  panels = [
    # Row 1: Overview Stats
    {
      type = "stat";
      title = "Total Queries";
      gridPos = { h = 4; w = 4; x = 0; y = 0; };
      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "short";
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_queries_total";
        refId = "A";
      }];
    }
    {
      type = "stat";
      title = "Cache Hits";
      gridPos = { h = 4; w = 4; x = 4; y = 0; };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        unit = "short";
        thresholds.mode = "absolute";
        thresholds.steps = [
          { color = "green"; value = null; }
        ];
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_cache_hits_total";
        refId = "A";
      }];
    }
    {
      type = "stat";
      title = "Cache Misses";
      gridPos = { h = 4; w = 4; x = 8; y = 0; };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        unit = "short";
        thresholds.mode = "absolute";
        thresholds.steps = [
          { color = "yellow"; value = null; }
        ];
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_cache_misses_total";
        refId = "A";
      }];
    }
    {
      type = "gauge";
      title = "Cache Hit Rate";
      gridPos = { h = 4; w = 4; x = 12; y = 0; };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        unit = "percentunit";
        min = 0;
        max = 1;
        thresholds.mode = "absolute";
        thresholds.steps = [
          { color = "red"; value = null; }
          { color = "yellow"; value = 0.5; }
          { color = "green"; value = 0.8; }
        ];
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_cache_hits_total / (unbound_cache_hits_total + unbound_cache_misses_total)";
        refId = "A";
      }];
    }
    {
      type = "stat";
      title = "Uptime";
      gridPos = { h = 4; w = 4; x = 16; y = 0; };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        unit = "s";
        thresholds.mode = "absolute";
        thresholds.steps = [
          { color = "green"; value = null; }
        ];
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_time_up_seconds_total";
        refId = "A";
      }];
    }
    {
      type = "stat";
      title = "Recursion Avg";
      gridPos = { h = 4; w = 4; x = 20; y = 0; };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        unit = "ms";
        thresholds.mode = "absolute";
        thresholds.steps = [
          { color = "green"; value = null; }
          { color = "yellow"; value = 100; }
          { color = "red"; value = 500; }
        ];
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_recursion_time_seconds_avg * 1000";
        refId = "A";
      }];
    }

    # Row 2: Query Rate Graph
    {
      type = "timeseries";
      title = "Query Rate";
      gridPos = { h = 8; w = 12; x = 0; y = 4; };
      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "reqps";
        custom = {
          lineWidth = 1;
          fillOpacity = 20;
          gradientMode = "scheme";
        };
      };
      options = {
        legend.displayMode = "list";
        legend.placement = "bottom";
      };
      targets = [
        {
          expr = "rate(unbound_queries_total[5m])";
          legendFormat = "Queries/s";
          refId = "A";
        }
        {
          expr = "rate(unbound_cache_hits_total[5m])";
          legendFormat = "Cache Hits/s";
          refId = "B";
        }
        {
          expr = "rate(unbound_cache_misses_total[5m])";
          legendFormat = "Cache Misses/s";
          refId = "C";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Recursion Time";
      gridPos = { h = 8; w = 12; x = 12; y = 4; };
      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "ms";
        custom = {
          lineWidth = 1;
          fillOpacity = 10;
        };
      };
      options = {
        legend.displayMode = "list";
        legend.placement = "bottom";
      };
      targets = [
        {
          expr = "unbound_recursion_time_seconds_avg * 1000";
          legendFormat = "Avg";
          refId = "A";
        }
        {
          expr = "unbound_recursion_time_seconds_median * 1000";
          legendFormat = "Median";
          refId = "B";
        }
      ];
    }

    # Row 3: Memory & Cache
    {
      type = "timeseries";
      title = "Memory Usage";
      gridPos = { h = 8; w = 12; x = 0; y = 12; };
      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "bytes";
        custom = {
          lineWidth = 1;
          fillOpacity = 20;
          stacking.mode = "normal";
        };
      };
      options = {
        legend.displayMode = "list";
        legend.placement = "bottom";
      };
      targets = [
        {
          expr = "unbound_memory_caches_bytes{cache=\"message\"}";
          legendFormat = "Message Cache";
          refId = "A";
        }
        {
          expr = "unbound_memory_caches_bytes{cache=\"rrset\"}";
          legendFormat = "RRset Cache";
          refId = "B";
        }
        {
          expr = "unbound_memory_caches_bytes{cache=\"key\"}";
          legendFormat = "Key Cache";
          refId = "C";
        }
      ];
    }
    {
      type = "timeseries";
      title = "Cache Entries";
      gridPos = { h = 8; w = 12; x = 12; y = 12; };
      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "short";
        custom = {
          lineWidth = 1;
          fillOpacity = 10;
        };
      };
      options = {
        legend.displayMode = "list";
        legend.placement = "bottom";
      };
      targets = [
        {
          expr = "unbound_msg_cache_count";
          legendFormat = "Message Cache";
          refId = "A";
        }
        {
          expr = "unbound_rrset_cache_count";
          legendFormat = "RRset Cache";
          refId = "B";
        }
      ];
    }

    # Row 4: DNSSEC & Answer Stats
    {
      type = "stat";
      title = "DNSSEC Secure";
      gridPos = { h = 4; w = 3; x = 0; y = 20; };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        unit = "short";
        thresholds.mode = "absolute";
        thresholds.steps = [
          { color = "green"; value = null; }
        ];
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_answers_secure_total";
        refId = "A";
      }];
    }
    {
      type = "stat";
      title = "RRset Bogus";
      gridPos = { h = 4; w = 3; x = 3; y = 20; };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        unit = "short";
        thresholds.mode = "absolute";
        thresholds.steps = [
          { color = "red"; value = null; }
        ];
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_rrset_bogus_total";
        refId = "A";
      }];
    }
    {
      type = "stat";
      title = "Answers Bogus";
      gridPos = { h = 4; w = 3; x = 6; y = 20; };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        unit = "short";
        thresholds.mode = "absolute";
        thresholds.steps = [
          { color = "red"; value = null; }
        ];
      };
      options.reduceOptions.calcs = [ "lastNotNull" ];
      targets = [{
        expr = "unbound_answers_bogus";
        refId = "A";
      }];
    }
    {
      type = "piechart";
      title = "Query Types";
      gridPos = { h = 8; w = 6; x = 9; y = 20; };
      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "short";
      };
      options = {
        legend = {
          displayMode = "table";
          placement = "right";
          values = [ "value" "percent" ];
        };
        pieType = "pie";
      };
      targets = [{
        expr = "unbound_query_types_total";
        legendFormat = "{{type}}";
        refId = "A";
      }];
    }
    {
      type = "piechart";
      title = "Answer RCodes";
      gridPos = { h = 8; w = 6; x = 15; y = 20; };
      fieldConfig.defaults = {
        color.mode = "palette-classic";
        unit = "short";
      };
      options = {
        legend = {
          displayMode = "table";
          placement = "right";
          values = [ "value" "percent" ];
        };
        pieType = "pie";
      };
      targets = [{
        expr = "unbound_answer_rcodes_total";
        legendFormat = "{{rcode}}";
        refId = "A";
      }];
    }
  ];
  refresh = "30s";
  schemaVersion = 38;
  tags = [ "dns" "unbound" ];
  templating.list = [ ];
  time = {
    from = "now-1h";
    to = "now";
  };
  timepicker = { };
  timezone = "browser";
  title = "Unbound DNS";
  uid = "unbound-dns";
  version = 1;
}

{
  config,
  pkgs,
  lib,
  ...
}:

let
  netSummaryScript =
    pkgs.writers.writePython3Bin "net-summary"
      {
        libraries = [
          pkgs.python3Packages.pandas
          pkgs.python3Packages.tabulate
        ];
        doCheck = false;
      }
      ''
        import pandas as pd
        import argparse
        import os
        import sys
        from datetime import datetime, timedelta
        from pathlib import Path

        LOG_DIR = Path(os.environ.get("NET_SUMMARY_LOG_DIR", "/var/log/network"))
        LOG_PATTERN = "systemd.csv*"

        def get_data(hours):
            log_files = sorted(LOG_DIR.glob(LOG_PATTERN))
            if not log_files:
                print(
                    f"Error: No {LOG_PATTERN} files found in {LOG_DIR}. "
                    "Wait for the one-minute timer to run."
                )
                sys.exit(1)

            frames = []
            for log_file in log_files:
                try:
                    # compression='infer' reads both the current CSV and rotated .gz files.
                    frame = pd.read_csv(log_file, compression='infer')
                except pd.errors.EmptyDataError:
                    continue
                frame['timestamp'] = pd.to_datetime(frame['timestamp'], utc=True)
                frames.append(frame)

            if not frames:
                print("No network history found in the retained CSV files.")
                sys.exit(0)

            df = pd.concat(frames, ignore_index=True)

            # Generate the start time as timezone-aware UTC
            start_time = pd.Timestamp.now(tz='UTC') - pd.Timedelta(hours=hours)

            # Now both sides are TZ-aware (UTC), enabling valid comparison
            df = df[df['timestamp'] >= start_time].copy()

            if df.empty:
                print("No data found for this time range.")
                sys.exit(0)

            return df

        def calculate_usage(df):
            # Sort to ensure time difference is calculated correctly
            df = df.sort_values(['unit', 'timestamp'])

            # Calculate the difference between rows (Usage = Current - Previous)
            df['down_mb'] = df.groupby('unit')['ingress_bytes'].diff().fillna(0) / 1024 / 1024
            df['up_mb'] = df.groupby('unit')['egress_bytes'].diff().fillna(0) / 1024 / 1024

            # HANDLE RESTARTS:
            # If 'diff' is negative, the service restarted and counter went to 0.
            # We assume the current counter value is the total usage since that restart.
            mask = df['down_mb'] < 0
            df.loc[mask, 'down_mb'] = df.loc[mask, 'ingress_bytes'] / 1024 / 1024

            mask = df['up_mb'] < 0
            df.loc[mask, 'up_mb'] = df.loc[mask, 'egress_bytes'] / 1024 / 1024

            return df

        def print_summary(hours):
            df = get_data(hours)
            df = calculate_usage(df)

            # Sum up usage per unit
            summary = df.groupby('unit')[['down_mb', 'up_mb']].sum().reset_index()
            summary['total_mb'] = summary['down_mb'] + summary['up_mb']

            # Sort by heaviest users
            summary = summary.sort_values('total_mb', ascending=False).head(20)

            print(f"\n=== Network Summary (Last {hours} Hours) ===")
            print(summary.to_markdown(index=False, floatfmt=".2f"))

        def print_timeline(hours, unit):
            df = get_data(hours)
            df = calculate_usage(df)

            # Filter for specific unit
            timeline = df[df['unit'] == unit].copy()

            if timeline.empty:
                print(f"No history found for unit: {unit}")
                return

            # Resample to hourly chunks.
            # We set the index to our UTC timestamp for resampling.
            timeline.set_index('timestamp', inplace=True)

            # Convert index to local time for display purposes if desired,
            # or keep as UTC. Here we keep it simple.
            hourly = timeline[['down_mb', 'up_mb']].resample('1h').sum()

            print(f"\n=== Hourly Timeline for {unit} ===")
            print(hourly.to_markdown(floatfmt=".2f"))


        if __name__ == "__main__":
            parser = argparse.ArgumentParser(description="Systemd Network Stats Viewer")
            parser.add_argument("--hours", type=int, default=24, help="How many hours back to analyze (default: 24)")
            parser.add_argument("--days", type=int, default=0, help="How many days back to analyze")
            parser.add_argument("--details", type=str, help="Show hourly breakdown for a specific service name")
            args = parser.parse_args()

            time_window = args.hours
            if args.days > 0:
                time_window = args.days * 24

            if args.details:
                print_timeline(time_window, args.details)
            else:
                print_summary(time_window)
      '';
in
{
  options.custom_modules.network_monitor.enable = lib.mkOption {
    description = "Enable custom systemd network monitor configuration.";
    type = lib.types.bool;
    default = false;
  };

  options.custom_modules.network_monitor.enableNtopng = lib.mkOption {
    description = "Enable ntopng within the network monitor module.";
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf config.custom_modules.network_monitor.enable {
    systemd.tmpfiles.rules = [
      "d /var/log/network 0755 root root -"
    ];

    systemd.services.systemd-net-logger = {
      description = "Export systemd IP counters to Prometheus and bounded CSV history";
      serviceConfig.Type = "oneshot";

      # 1. Provide necessary tools
      path = with pkgs; [
        gawk
        findutils
        coreutils
      ];

      script = ''
        LOG_FILE="/var/log/network/systemd.csv"
        PROM_FILE="/var/lib/node_exporter/textfile_collector/systemd.prom"
        PROM_TMP="/var/lib/node_exporter/textfile_collector/systemd.prom.tmp"
        TIMESTAMP=$(date -Iseconds)

        # Ensure directory exists
        mkdir -p "$(dirname "$PROM_TMP")"

        # logrotate creates an empty replacement after each daily rotation.
        if [ ! -s "$LOG_FILE" ]; then
          echo "timestamp,unit,ingress_bytes,egress_bytes" > "$LOG_FILE"
        fi

        ${pkgs.systemd}/bin/systemctl list-units --type=service --state=running --no-legend --no-pager \
        | awk '{print $1}' \
        | xargs ${pkgs.systemd}/bin/systemctl show -p Id -p IPIngressBytes -p IPEgressBytes \
        | awk -v date="$TIMESTAMP" -v prom_file="$PROM_TMP" -F= '
            BEGIN {
              # Initialize Prometheus file with header
              print "# HELP systemd_unit_ingress_bytes Total ingress bytes for systemd unit" > prom_file;
              print "# TYPE systemd_unit_ingress_bytes counter" > prom_file;
              print "# HELP systemd_unit_egress_bytes Total egress bytes for systemd unit" > prom_file;
              print "# TYPE systemd_unit_egress_bytes counter" > prom_file;
            }

            # 2. Reset variables for every new Unit ID to prevent leaking
            /^Id=/ {
              id=$2;
              input=0;
              output=0;
              has_input=0;
              has_output=0;
            }

            # 3. Filter out "unset" values (UINT64_MAX) and non-numbers
            /^IPIngressBytes=/ {
              if ($2 ~ /^[0-9]+$/ && $2 != "18446744073709551615") { input=$2; has_input=1; }
            }
            /^IPEgressBytes=/ {
              if ($2 ~ /^[0-9]+$/ && $2 != "18446744073709551615") { output=$2; has_output=1; }

              # 4. Only log if we actually found valid traffic data
              if ((has_input || has_output) && (input > 0 || output > 0)) {
                 # CSV Output (to stdout -> LOG_FILE)
                 printf "%s,%s,%s,%s\n", date, id, input, output

                 # Prometheus Output (to prom_file)
                 print "systemd_unit_ingress_bytes{unit=\"" id "\"} " input > prom_file;
                 print "systemd_unit_egress_bytes{unit=\"" id "\"} " output > prom_file;
              }
            }
          ' >> "$LOG_FILE"

          # Atomically update the prometheus file
          mv "$PROM_TMP" "$PROM_FILE"
      '';
    };

    # Keep one-minute samples: the network dashboard uses five-minute irate
    # windows, and hourly collection would leave those panels mostly empty.
    systemd.timers.systemd-net-logger = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/1";
        Persistent = true; # Run once after startup if a minute was missed.
        Unit = "systemd-net-logger.service";
      };
    };

    # The CSV backs the local net-summary CLI. At the observed growth rate of
    # roughly 5 MiB/day, 31 daily archives bound raw retention near 160 MiB
    # before compression while Prometheus remains the long-term history store.
    services.logrotate.settings.systemd-network-csv = {
      files = [ "/var/log/network/systemd.csv" ];
      frequency = "daily";
      rotate = 31;
      compress = true;
      delaycompress = false;
      dateext = true;
      maxsize = "25M";
      missingok = true;
      notifempty = true;
      create = "0644 root root";
    };

    services.vnstat.enable = true;
    services.ntopng = lib.mkIf config.custom_modules.network_monitor.enableNtopng {
      enable = true;
      httpPort = 3123;
      extraConfig = ''
        --http-prefix="/ntopng"
      '';
    };

    environment.systemPackages = [ netSummaryScript ];
  };
}

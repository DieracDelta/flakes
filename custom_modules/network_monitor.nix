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
        import sys
        from datetime import datetime, timedelta

        LOG_FILE = "/var/log/network/systemd.csv"

        def get_data(hours):
            try:
                # Read CSV. We don't rely on automatic parsing in read_csv
                # to ensure we can control the UTC conversion explicitly below.
                df = pd.read_csv(LOG_FILE)
            except FileNotFoundError:
                print(f"Error: Log file {LOG_FILE} not found. Wait for the hourly timer to run.")
                sys.exit(1)

            # Convert timestamp column to timezone-aware UTC
            # This handles the mixed offsets (e.g. -05:00) provided by `date -Iseconds`
            df['timestamp'] = pd.to_datetime(df['timestamp'], utc=True)

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

  config = lib.mkIf config.custom_modules.network_monitor.enable {
    systemd.tmpfiles.rules = [
      "d /var/log/network 0755 root root -"
    ];

    systemd.services.systemd-net-logger = {
      description = "Log Systemd IP Counters to CSV";
      serviceConfig.Type = "oneshot";

      # 1. Provide necessary tools
      path = with pkgs; [
        gawk
        findutils
        coreutils
      ];

      script = ''
        LOG_FILE="/var/log/network/systemd.csv"
        TIMESTAMP=$(date -Iseconds)

        if [ ! -f "$LOG_FILE" ]; then
          echo "timestamp,unit,ingress_bytes,egress_bytes" > "$LOG_FILE"
        fi

        ${pkgs.systemd}/bin/systemctl list-units --type=service --state=running --no-legend --no-pager \
        | awk '{print $1}' \
        | xargs ${pkgs.systemd}/bin/systemctl show -p Id -p IPIngressBytes -p IPEgressBytes \
        | awk -v date="$TIMESTAMP" -F= '
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
                 printf "%s,%s,%s,%s\n", date, id, input, output
              }
            }
          ' >> "$LOG_FILE"
      '';
    };

    # 4. The Timer (Runs exactly at :00 every hour)
    systemd.timers.systemd-net-logger = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true; # Run immediately if we missed the last hour while off
        Unit = "systemd-net-logger.service";
      };
    };

    environment.systemPackages = [ netSummaryScript ];
  };
}

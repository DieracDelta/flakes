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
                df = pd.read_csv(LOG_FILE, parse_dates=['timestamp'])
            except FileNotFoundError:
                print(f"Error: Log file {LOG_FILE} not found. Wait for the hourly timer to run.")
                sys.exit(1)

            # Filter by time window
            start_time = datetime.now() - timedelta(hours=hours)
            df = df[df['timestamp'] >= start_time].copy()

            if df.empty:
                print("No data found for this time range.")
                sys.exit(0)

            return df

        def calculate_usage(df):
            # Sort to ensure time difference is calculated correctly
            df = df.sort_values(['unit', 'timestamp'])

            # Calculate the difference between rows (Usage = Current - Previous)
            # We group by 'unit' so we don't subtract Service A from Service B
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

            # Resample to hourly chunks to smooth out the table
            timeline.set_index('timestamp', inplace=True)
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
            /^Id=/ { id=$2 }
            /^IPIngressBytes=/ { input=$2 }
            /^IPEgressBytes=/ { output=$2; if (input > 0 || output > 0) printf "%s,%s,%s,%s\n", date, id, input, output }
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

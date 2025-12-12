{
  config,
  pkgs,
  lib,
  ...
}:

let
  # --- 1. The Recorder Script (Runs for 1 hour, saves, exits) ---
  nethogsRecorder =
    pkgs.writers.writePython3Bin "nethogs-recorder"
      {
        libraries = [ ];
        doCheck = false;
      }
      ''
        import subprocess
        import time
        import sys
        import os
        import re
        from datetime import datetime

        # Settings
        DURATION_SECONDS = 3600  # Run for 1 hour
        LOG_FILE = "/var/log/network/nethogs_history.csv"

        # Ensure log dir exists
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

        # Initialize CSV if new
        if not os.path.exists(LOG_FILE):
            with open(LOG_FILE, "w") as f:
                f.write("timestamp,process,upload_mb,download_mb\n")

        print(f"Starting nethogs recorder for {DURATION_SECONDS} seconds...")

        # Start nethogs
        # -t: trace mode
        # -d 30: update internal counter every 30s (we don't need 1s updates for hourly totals)
        # -v 3: MB mode
        cmd = ["${pkgs.nethogs}/bin/nethogs", "-t", "-d", "30", "-v", "3"]
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        start_time = time.time()
        final_totals = {} # Stores { "process_name": [upload, download] }

        try:
            while True:
                # Check if time is up
                if time.time() - start_time > DURATION_SECONDS:
                    break

                # Read line non-blocking (ish)
                line = process.stdout.readline()
                if not line:
                    if process.poll() is not None: break
                    continue

                line = line.strip()

                # Parse lines like: "process_name/pid/uid   1.23   4.56"
                # We skip headers and "Refreshing:"
                if "Refreshing:" in line or "Ethernet link" in line or "Adding local" in line or not line:
                    continue

                parts = line.split()
                # We expect at least 3 parts: [Process, Sent, Recv]
                if len(parts) >= 3:
                    try:
                        # In trace mode -v 3, columns are usually: Process | Sent(MB) | Recv(MB)
                        proc_name = parts[0]
                        sent = float(parts[1])
                        recv = float(parts[2])

                        # Since nethogs accumulates, the LATEST value we see is the CURRENT TOTAL.
                        # We continually overwrite the entry for this process.
                        final_totals[proc_name] = [sent, recv]
                    except ValueError:
                        continue

        except KeyboardInterrupt:
            pass
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except:
                process.kill()

        # --- SAVE TO CSV ---
        timestamp = datetime.now().isoformat(timespec='seconds')
        print(f"Writing stats for {len(final_totals)} processes to {LOG_FILE}")

        with open(LOG_FILE, "a") as f:
            for proc, stats in final_totals.items():
                # If totals are effectively zero, skip to save space (optional)
                if stats[0] < 0.01 and stats[1] < 0.01:
                    continue
                f.write(f"{timestamp},{proc},{stats[0]:.4f},{stats[1]:.4f}\n")
      '';

  # --- 2. The Viewer Script (Reads the clean CSVs) ---
  nethogsViewer =
    pkgs.writers.writePython3Bin "net-summary-nh"
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
        from datetime import datetime, timedelta
        import sys

        LOG_FILE = "/var/log/network/nethogs_history.csv"

        def main():
            parser = argparse.ArgumentParser(description="Network Usage Summary")
            parser.add_argument("--hours", type=int, default=24, help="Hours back")
            args = parser.parse_args()

            try:
                df = pd.read_csv(LOG_FILE)
            except FileNotFoundError:
                print("No logs found yet. Wait for the first hour to complete.")
                sys.exit(1)

            # Convert timestamp strings to datetime objects
            df['timestamp'] = pd.to_datetime(df['timestamp'])

            # Filter by time
            start_time = datetime.now() - timedelta(hours=args.hours)
            df = df[df['timestamp'] >= start_time]

            if df.empty:
                print("No data in the selected time range.")
                sys.exit(0)

            # Simplify Process Names (remove /nix/store/... clutter)
            # Regex replacement could go here, but simple split helps readability
            def clean_name(name):
                if "/nix/store/" in name:
                    parts = name.split('/')
                    # Return the binary name (last part usually, or near end)
                    # Example: .../bin/python3.11/pid/uid -> python3.11
                    return parts[-3] if "bin" in parts else name
                return name

            # Group by Process Name and Sum
            # Since each row in CSV represents a distinct 1-hour block, we simply SUM them up.
            grouped = df.groupby('process')[['upload_mb', 'download_mb']].sum().reset_index()
            grouped['total_mb'] = grouped['upload_mb'] + grouped['download_mb']

            # Sort
            grouped = grouped.sort_values('total_mb', ascending=False).head(20)

            print(f"\n=== Network Traffic (Last {args.hours} Hours) ===")
            print(grouped.to_markdown(index=False, floatfmt=".2f"))

        if __name__ == "__main__":
            main()
      '';

in
{
  options.custom_modules.nethog_monitor.enable = lib.mkOption {
    description = "Enable custom nethog configuration.";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf config.custom_modules.nethog_monitor.enable {

    # 1. Create Log Directory
    systemd.tmpfiles.rules = [
      "d /var/log/network 0755 root root -"
    ];

    # 2. The Service
    systemd.services.nethogs-recorder = {
      description = "Hourly Nethogs Batch Recorder";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "root";
        # Run the python script directly
        ExecStart = "${nethogsRecorder}/bin/nethogs-recorder";
        # VITAL: When the script finishes (after 1 hour), restart it immediately.
        Restart = "always";
        RestartSec = "1s";
      };
    };

    services.logrotate.settings.nethogs-csv = {
      files = [ "/var/log/network/nethogs_history.csv" ];
      frequency = "monthly";
      rotate = 6;
    };

    environment.systemPackages = [ nethogsViewer ];

  };
}

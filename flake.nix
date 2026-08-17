{
  description = "A highly awesome system configuration.";

  inputs = {
    hl.url = "github:pamburus/hl";
    hl.inputs.nixpkgs.follows = "nixpkgs-unpatched";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unpatched";
    strace_macos.url = "github:Mic92/strace-macos";
    strace_macos.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    my-nvim.url = "github:DieracDelta/vimconfig";
    # Its original nested pin predates fetchCargoVendor's crates.io
    # data-policy User-Agent and deterministically receives HTTP 403. Pin the
    # first compatible post-fix nixpkgs staging commit: current master cannot
    # be followed yet because its new neovim `wasmSupport` override API is not
    # supported by my-nvim's pinned neovim-nightly-overlay.
    my-nvim.inputs.nixpkgs.url = "github:NixOS/nixpkgs/2a0e0baec1c99cdc087c14f83ac6c31c929d14eb";

    nix.url = "github:NixOS/nix/2.35.1";
    nix.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    nixified-ai.url = "github:nixified-ai/flake";
    nixified-ai.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    nixpkgs-unpatched.url = "github:NixOS/nixpkgs/master";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    # Required to evaluate the upstream Pijul Nest flake fetched by fetchpijul.
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    # wger workout/nutrition tracker (pinned upstream; dirty local checkouts are preserved separately)
    wger.url = "github:wger-project/wger/e1d70bcc38cd56ae4a254dca1713c404d069f319";
    wger.flake = false;
    wger-react.url = "github:wger-project/react/28f70598160ccfb76c88c04f9bfe2d08ecd482fd";
    wger-react.flake = false;
    wger-flutter.url = "github:wger-project/flutter/2.0.3";
    wger-flutter.flake = false;

    # CalDAV calendar web frontend; pin the clean upstream commit rather than
    # consuming the local checkout (which contains an untracked result link).
    caldav-calendar-web.url = "github:DieracDelta/webdav-cal-simple/fc56170b2a71e1bd7ccf774c3f9b8b81717621de";
    caldav-calendar-web.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    # Rotki portfolio tracker: v1.43.2 local-premium/Cardano/NEAR port in an
    # isolated clean upgrade tree. The original dirty checkout remains intact.
    rotki.url = "path:/home/jrestivo/dev/rotki-1.43.2-upgrade";
    # Compatibility exception: this flake currently hard-codes pnpm fetcher v3
    # with the default pnpm. Following master selects pnpm 11 and fails during
    # evaluation. Keep its pin until the upstream patch in this audit lands.

    # Plane MCP server (pinned release; the dirty local development checkout is preserved separately)
    plane-mcp-server-src.url = "github:makeplane/plane-mcp-server/96cf4d51d65cfa5e47d10ff7a4a4caba3b7a98d1";
    plane-mcp-server-src.flake = false;

    # Repowise codebase intelligence MCP server
    repowise-src.url = "github:repowise-dev/repowise/v0.39.0";
    repowise-src.flake = false;

    # Octo-Fiesta Subsonic proxy for WRhythm/Navidrome testing
    octo-fiesta-src.url = "github:V1ck3s/octo-fiesta/v0.10";
    octo-fiesta-src.flake = false;

    # eBPF process monitor
    bpftop.url = "github:DieracDelta/bpftop";
    bpftop.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    # PSI coding agent
    psi-coding-agent.url = "git+ssh://forgejo@office-desktop.tail5ca7.ts.net/jrestivo/psi-coding-agent.git?ref=feature/aggregate-prs-63-55-51-33";
    psi-coding-agent.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    # eBPF per-process bandwidth shaping daemon
    shapebpf.url = "github:DieracDelta/shapeBPF";
    shapebpf.inputs.nixpkgs.follows = "nixpkgs-unpatched";

    # Declarative Postfix/Dovecot/Rspamd mail stack.
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/main";
    simple-nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs-unpatched";
  };

  outputs =
    inputs@{
      self,
      nixpkgs-unpatched,
      ...
    }:
    let
      nixpkgs = nixpkgs-unpatched;

      # Import platform-specific builders
      myLib = import ./lib {
        inputs = inputs // {
          inherit nixpkgs;
        };
      };

      inherit (nixpkgs-unpatched) lib;
    in
    {
      # x86_64-linux NixOS configurations (auto-discovered from hosts/*.nixos.nix)
      nixosConfigurations =
        let
          # Auto-discover x86_64 hosts (excluding nixos-arm)
          x86Dirs = lib.filterAttrs (
            name: fileType:
            (fileType == "regular") && (lib.hasSuffix ".nixos.nix" name) && (name != "nixos-arm.nixos.nix")
          ) (builtins.readDir ./hosts);
          x86Paths = lib.mapAttrsToList (name: _v: ./. + "/hosts/${name}") x86Dirs;
        in
        myLib.x86_64-linux.buildNixosConfigurations x86Paths
        // {
          # ARM NixOS (separate builder, no znver3/CUDA)
          nixos-arm = myLib.aarch64-linux.buildNixosConfiguration "nixos-arm" (
            import ./hosts/nixos-arm.nixos.nix
          );
        };

      # Darwin (macOS) configurations
      darwinConfigurations."jrestivo-4" = myLib.aarch64-darwin.buildDarwinConfiguration "jrestivo-4";

      # Standalone Home Manager configuration using the same configured package
      # set as the NixOS desktop.
      homeConfigurations.jrestivo = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = myLib.x86_64-linux.pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home/home.nix
          {
            home.username = "jrestivo";
            home.homeDirectory = "/home/jrestivo";
          }
        ];
      };

      # Regression check for the network monitor's documented collection and
      # bounded-retention policy.
      checks.x86_64-linux.network-monitor-config =
        let
          cfg = self.nixosConfigurations.desktop.config;
          pkgs = myLib.x86_64-linux.pkgs;
          timer = cfg.systemd.timers.systemd-net-logger.timerConfig;
          rotation = cfg.services.logrotate.settings.systemd-network-csv;
        in
        pkgs.runCommand "network-monitor-config-check"
          {
            nativeBuildInputs = [ pkgs.gnugrep ];
          }
          ''
            test ${lib.escapeShellArg timer.OnCalendar} = '*:0/1'
            test ${toString rotation.rotate} -eq 31
            test ${lib.escapeShellArg rotation.frequency} = daily
            test ${lib.escapeShellArg (lib.boolToString rotation.compress)} = true
            grep -F '"/var/log/network/systemd.csv"' ${cfg.services.logrotate.configFile}
            grep -F 'maxsize 25M' ${cfg.services.logrotate.configFile}
            touch "$out"
          '';

      # Ensure cgroup attribution never hides whole-device I/O. The SMART
      # dashboard must expose both reads and writes plus their unattributed
      # filesystem/kernel remainder, and all generated Prometheus rules must
      # remain valid.
      checks.x86_64-linux.disk-io-attribution-config =
        let
          cfg = self.nixosConfigurations.desktop.config;
          pkgs = myLib.x86_64-linux.pkgs;
          dashboard = pkgs.writeText "smart-dashboard.json" (
            cfg.environment.etc."grafana-dashboards/smart/smart-dashboard.json".text
          );
          rules = pkgs.writeText "prometheus-rules.yml" (
            builtins.concatStringsSep "\n" cfg.services.prometheus.rules
          );
          collector = cfg.systemd.services.prometheus-user-cgroup-io.serviceConfig.ExecStart;
          alertmanagerConfig = pkgs.writeText "alertmanager.json" (
            builtins.toJSON cfg.services.prometheus.alertmanager.configuration
          );
          alertmanagerWiring = pkgs.writeText "alertmanager-wiring.json" (
            builtins.toJSON {
              inherit (cfg.services.prometheus) alertmanagers;
              conditions = cfg.systemd.services.alertmanager.unitConfig.ConditionPathExists;
              credentials = cfg.systemd.services.alertmanager.serviceConfig.LoadCredential;
            }
          );
        in
        pkgs.runCommand "disk-io-attribution-config-check"
          {
            nativeBuildInputs = [
              pkgs.envsubst
              pkgs.jq
              pkgs.prometheus.cli
              cfg.services.prometheus.alertmanager.package
            ];
          }
          ''
            promtool check rules ${rules}
            jq -e '
              any(.panels[]; .title == "Physical Write Attribution by Drive") and
              any(.panels[]; .title == "Physical Read Attribution by Drive") and
              any(.panels[]; .title == "Physical Writes by Source — Selected Range") and
              any(.panels[]; .title == "Physical Reads by Source — Selected Range") and
              any(.panels[]; .title == "System Service Write Throughput") and
              any(.panels[]; .title == "System Service Read Throughput")
            ' ${dashboard} >/dev/null
            grep -F 'node_disk_unattributed_write_bytes_per_second' ${rules}
            grep -F 'node_disk_unattributed_read_bytes_per_second' ${rules}
            grep -F 'systemd_service_cgroup_io_write_bytes_per_second' ${rules}
            grep -F 'systemd_service_cgroup_io_read_bytes_per_second' ${rules}
            grep -F 'alert: PhysicalDiskWriteRateHigh' ${rules}
            grep -F 'alert: UnattributedDiskWriteRateHigh' ${rules}
            grep -F 'alert: PhysicalDiskWrites24hWarning' ${rules}
            grep -F 'alert: PhysicalDiskWrites24hCritical' ${rules}
            grep -F 'alert: UnattributedDiskWrites24hWarning' ${rules}
            grep -F 'alert: UnattributedDiskWrites24hCritical' ${rules}

            alertmanager_fixture="$TMPDIR/alertmanager-fixture"
            mkdir -p "$alertmanager_fixture"
            printf '%s\n' '123456789:fixture-token' > "$alertmanager_fixture/telegram-bot-token"
            printf '%s\n' '123456789' > "$alertmanager_fixture/telegram-chat-id"
            CREDENTIALS_DIRECTORY="$alertmanager_fixture" \
              envsubst -i ${alertmanagerConfig} -o "$alertmanager_fixture/alertmanager.json"
            amtool check-config "$alertmanager_fixture/alertmanager.json"
            jq -e '
              .route.group_by == ["category"] and
              .route.group_wait == "5m" and
              .route.group_interval == "1h" and
              .route.repeat_interval == "24h" and
              any(.receivers[]; .name == "telegram-silent") and
              any(.receivers[]; .name == "telegram-critical")
            ' "$alertmanager_fixture/alertmanager.json" >/dev/null
            jq -e '
              .alertmanagers[0].static_configs[0].targets == ["127.0.0.1:9093"] and
              (.conditions | length) == 2 and
              (.credentials | length) == 2
            ' ${alertmanagerWiring} >/dev/null

            fixture="$TMPDIR/cgroup-fixture"
            mkdir -p \
              "$fixture/cgroup/system.slice/nix-daemon.service" \
              "$fixture/cgroup/system.slice/transient-123.service" \
              "$fixture/systemd-units" \
              "$fixture/sys-dev-block" \
              "$fixture/devices/nvme0n1"
            touch "$fixture/systemd-units/nix-daemon.service"
            ln -s "$fixture/devices/nvme0n1" "$fixture/sys-dev-block/259:0"
            printf '%s\n' \
              '259:0 rbytes=2000 wbytes=1000 rios=20 wios=10' \
              > "$fixture/cgroup/system.slice/io.stat"
            printf '%s\n' \
              '259:0 rbytes=800 wbytes=456 rios=8 wios=4' \
              > "$fixture/cgroup/system.slice/nix-daemon.service/io.stat"
            printf '%s\n' \
              '259:0 rbytes=9000 wbytes=9000 rios=90 wios=90' \
              > "$fixture/cgroup/system.slice/transient-123.service/io.stat"
            USER_CGROUP_IO_OUTPUT="$fixture/metrics.prom" \
              USER_CGROUP_IO_CGROUP_ROOT="$fixture/cgroup" \
              USER_CGROUP_IO_SYS_DEV_BLOCK_ROOT="$fixture/sys-dev-block" \
              USER_CGROUP_IO_SYSTEMD_UNIT_ROOTS="$fixture/systemd-units" \
              ${collector}
            grep -F 'user_cgroup_io_write_bytes_total{user="system",uid="system",cgroup="system.slice",device="nvme0n1",major_minor="259:0"} 1000' \
              "$fixture/metrics.prom"
            grep -F 'systemd_service_cgroup_io_write_bytes_total{unit="nix-daemon.service",cgroup="system.slice/nix-daemon.service",device="nvme0n1",major_minor="259:0"} 456' \
              "$fixture/metrics.prom"
            grep -F 'systemd_service_cgroup_io_collector_units 1' "$fixture/metrics.prom"
            if grep -F 'transient-123.service' "$fixture/metrics.prom"; then
              echo 'transient service unexpectedly exported' >&2
              exit 1
            fi
            touch "$out"
          '';

      # Hydra CI jobs
      hydraJobs.x86_64-linux.desktop = self.nixosConfigurations.desktop.config.system.build.toplevel;

      # Debug outputs
      mything = myLib.x86_64-linux.pkgs;
      mything2 = nixpkgs.outPath;
    };
}

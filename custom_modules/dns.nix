{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.dns;
in
{
  options.custom_modules.dns.enable = mkOption {
    description = "Enable DNS stack: AdGuard Home (ad-blocking) + Unbound (recursive resolver with rebinding protection).";
    type = with types; bool;
    default = false;
  };

  config = mkIf cfg.enable {
    # ===================
    # Unbound - Recursive DNS resolver
    # ===================
    services.unbound = {
      enable = true;
      settings = {
        server = {
          # Listen only on localhost - AdGuard forwards to us
          interface = [ "127.0.0.1" ];
          port = 5335;

          # Access control
          access-control = [
            "127.0.0.0/8 allow"
            "::1/128 allow"
          ];

          # DNS rebinding protection - block private IPs in responses from upstream
          # Prevents malicious domains from resolving to internal addresses
          private-address = [
            "10.0.0.0/8"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "169.254.0.0/16"
            "fd00::/8"
            "fe80::/10"
            "127.0.0.0/8"
            "::1/128"
            # Note: Tailscale CGNAT (100.64.0.0/10) intentionally NOT blocked
          ];

          # Root hints for recursive resolution
          root-hints = "${pkgs.dns-root-data}/root.hints";

          # Performance tuning
          num-threads = 4;
          prefetch = true;
          prefetch-key = true;

          # Cache settings
          cache-min-ttl = 300;
          cache-max-ttl = 86400;

          # Serve stale data while refreshing
          serve-expired = true;
          serve-expired-ttl = 86400;

          # Harden against attacks
          harden-glue = true;
          harden-dnssec-stripped = true;
          harden-below-nxdomain = true;
          harden-referral-path = true;

          # Privacy - minimize query info sent to authoritative servers
          qname-minimisation = true;
          qname-minimisation-strict = false;

          # Hide identity and version
          hide-identity = true;
          hide-version = true;

          # Additional security hardening
          aggressive-nsec = true;           # Use NSEC records to deny non-existent domains (faster NXDOMAIN)
          deny-any = true;                  # Refuse ANY queries (prevents amplification attacks)
          val-clean-additional = true;      # Remove untrusted data from additional section
          minimal-responses = true;         # Only return requested data, reduce info leakage
          unwanted-reply-threshold = 10000; # Detect/ignore spoofed replies (threshold before warning)

          # Logging
          verbosity = 1;
          statistics-interval = 0;

          # Buffer sizes
          so-rcvbuf = "1m";
          so-sndbuf = "1m";
          msg-cache-size = "50m";
          rrset-cache-size = "100m";

          # Enable extended statistics for Prometheus exporter
          extended-statistics = true;
        };

        # Enable remote control for Prometheus exporter
        remote-control = {
          control-enable = true;
          control-interface = "127.0.0.1";
        };
      };
    };

    # Prometheus exporter for Unbound metrics (port 9167)
    services.prometheus.exporters.unbound = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9167;
    };

    # ===================
    # AdGuard Home - Ad-blocking DNS frontend
    # ===================
    services.adguardhome = {
      enable = true;
      mutableSettings = false;  # NixOS controls config, ensures upstream settings are applied
      port = 3003;  # Web UI port
      settings = {
        http = {
          address = "127.0.0.1:3003";
        };
        dns = {
          bind_hosts = [ "0.0.0.0" ];
          port = 53;
          ratelimit = 1000;
          upstream_dns = [
            "127.0.0.1:5335"                      # Local Unbound (primary)
            "9.9.9.9"                             # Quad9 plain DNS (fallback)
          ];
          bootstrap_dns = [
            "9.9.9.9"                             # Quad9 IP
          ];
          # Use Unbound for reverse DNS of private IPs
          local_ptr_upstreams = [ "127.0.0.1:5335" ];
          # Disable IPv6 responses - IPv6 is unreachable and may cause client hangs
          aaaa_disabled = true;
        };
      };
    };

    # Ensure Unbound waits for network and retries on failure
    systemd.services.unbound = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # Ensure Unbound starts before AdGuard
    systemd.services.adguardhome = {
      wants = [ "unbound.service" ];
      after = [ "unbound.service" ];
    };

    # Firewall
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    # Add Unbound to Prometheus scrape targets
    services.prometheus.scrapeConfigs = [
      {
        job_name = "unbound";
        static_configs = [
          { targets = [ "127.0.0.1:9167" ]; }
        ];
      }
    ];

    # Grafana dashboard for Unbound
    services.grafana.provision.dashboards.settings.providers = [
      {
        name = "unbound-dashboard";
        orgId = 1;
        folder = "DNS";
        type = "file";
        disableDeletion = false;
        editable = true;
        allowUIUpdates = true;
        options.path = "/etc/grafana-dashboards/unbound";
      }
    ];

    environment.etc."grafana-dashboards/unbound/unbound-dashboard.json" = {
      text = builtins.toJSON (import ./dashboards/unbound.nix);
      user = "grafana";
      group = "grafana";
      mode = "0644";
    };
  };
}

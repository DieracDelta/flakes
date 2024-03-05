{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.custom_modules.nextcloud;
in
{
  options.custom_modules.nextcloud.enable = mkOption {
    description = "Enable custom Nextcloud configuration.";
    type = with types; bool;
    default = false;
  };
  config = mkIf cfg.enable {
    # /*# Enable Nginx*/
    # services.nginx = {
    #   enable = true;
    #
    #   # Use recommended settings
    #   recommendedGzipSettings = true;
    #   recommendedOptimisation = true;
    #   recommendedProxySettings = true;
    #   recommendedTlsSettings = true;
    #
    #   # Setup Nextcloud virtual host to listen on ports
    #   virtualHosts = {
    #
    #     "localhost" = {
    #       ## Force HTTP redirect to HTTP
    #       forceSSL = false;
    #     };
    #   };
    # };
    #
    # services.postgresql = {
    #   enable = true;
    #
    #   # Ensure the database, user, and permissions always exist
    #   ensureDatabases = [ "nextcloud" ];
    #   ensureUsers = [
    #     {
    #       name = "nextcloud";
    #       ensurePermissions."DATABASE nextcloud" = "ALL PRIVILEGES";
    #     }
    #   ];
    # };
    # services.nextcloud = {
    #   package = pkgs.nextcloud21;
    #   enable = true;
    #   hostName = "localhost";
    #   config.extraTrustedDomains = [ "localhost" "192.168.196.233" "192.168.196.136" "192.168.196.17" "100.107.190.11" "100.100.105.124" "100.83.203.21" ];
    #
    #   # Use HTTP for links
    #   https = false;
    #
    #   # Auto-update Nextcloud Apps
    #   autoUpdateApps.enable = true;
    #   # Set what time makes sense for you
    #   autoUpdateApps.startAt = "05:00:00";
    #
    #   config = {
    #     # Further forces Nextcloud to use HTTP (need ssl certs for https)
    #     overwriteProtocol = "http";
    #
    #     # Nextcloud PostegreSQL database configuration, recommended over using SQLite
    #     dbtype = "pgsql";
    #     dbuser = "nextcloud";
    #     dbpass = "bruh6969";
    #     dbhost = "/run/postgresql";
    #     dbname = "nextcloud";
    #
    #     adminuser = "admin";
    #     # adminpass = "bruh6969";
    #   };
    # };
    # systemd.services."nextcloud-setup" = {
    #   requires = [ "postgresql.service" ];
    #   after = [ "postgresql.service" ];
    # };
    # networking.firewall.allowedTCPPorts = [ 3389 80 443 444 ];
  };
}

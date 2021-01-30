{ config, pkgs, lib, ... }:
{
  /*security.acme = {*/
    /*acceptTerms = true;*/
    /*# Replace the email here!*/
    /*email = "justin@restivo.me";*/
  /*};*/

  /*# Enable Nginx*/
  services.nginx = {
    enable = true;

    # Use recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Setup Nextcloud virtual host to listen on ports
    virtualHosts = {

      "nextcloud.local" = {
        ## Force HTTP redirect to HTTPS
        /*forceSSL = true;*/
        ## LetsEncrypt
        /*enableACME = true;*/
      };
    };
    /*appendHttpConfig = "listen 127.0.0.1:80";*/
  };

  services.postgresql = {
    enable = true;

    # Ensure the database, user, and permissions always exist
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
    { name = "nextcloud";
      ensurePermissions."DATABASE nextcloud" = "ALL PRIVILEGES";
    }
    ];
  };
  services.nextcloud = {
    package = pkgs.nextcloud20;
    enable = true;
    hostName = "nextcloud.local";
    config.extraTrustedDomains = [ "localhost" "192.168.196.233" "192.168.196.136" "192.168.196.17"];

    # Enable built-in virtual host management
    # Takes care of somewhat complicated setup
    # See here: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/nextcloud.nix#L529

    # Use HTTPS for links
    https = false;

    # Auto-update Nextcloud Apps
    autoUpdateApps.enable = true;
    # Set what time makes sense for you
    autoUpdateApps.startAt = "05:00:00";

    config = {
      # Further forces Nextcloud to use HTTPS
      overwriteProtocol = "http";

      # Nextcloud PostegreSQL database configuration, recommended over using SQLite
      dbtype = "pgsql";
      dbuser = "nextcloud";
      dbpass = "bruh6969";
      dbhost = "/run/postgresql"; # nextcloud will add /.s.PGSQL.5432 by itself
      dbname = "nextcloud";
      /*dbpassFile = "/var/nextcloud-db-pass";*/

      /*adminpassFile = "/var/nextcloud-admin-pass";*/
      adminuser = "admin";
      adminpass = "bruh6969";
    };
  };
  systemd.services."nextcloud-setup" = {
    requires = ["postgresql.service"];
    after = ["postgresql.service"];
  };
  networking.firewall.allowedTCPPorts = [ 3389 80 443 444];

}

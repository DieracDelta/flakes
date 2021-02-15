{ config, pkgs, lib, ... }:
let
  cfg = config.custom_modules.rust-filehost;
in
{
  options.custom_modules.rust-filehost.enable =
    lib.mkOption {
      description = "Enable custom Filehost module.";
      type = lib.types.bool;
      default = false;
    };
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 8000];
    security.acme = {
      acceptTerms = true;
      # Replace the email here!
      email = "justin@restivo.me";
    };
    services.nginx = {
      enable = true;
      # Use recommended settings
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # Only allow PFS-enabled ciphers with AES256
      /*sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";*/
    # Setup Nextcloud virtual host to listen on ports
      virtualHosts = {
        "filehost.restivo.me" = {
          ## Force HTTP redirect to HTTPS
          forceSSL = true;
          ## LetsEncrypt
          enableACME = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:8000";
            proxyWebsockets = true; # needed if you need to use WebSocket
            extraConfig =
              # required when the server wants to use HTTP Authentication
              "proxy_pass_header Authorization;"
              ;
          };
        };
      };
    };
    systemd.services.rust-filehost = {
       wantedBy = [ "multi-user.target" ];
       after = [ "network.target" ];
       description = "Start the rust filehost service.";
       serviceConfig = {
         Type = "simple";
         EnvironmentFile = config.sops.secrets.rust_filehost_secrets.path;
         ExecStart = ''${pkgs.rust-filehost}/bin/filehost'';
         /*ExecStart = ''${pkgs.coreutils}/bin/cat /var/lib/acme/filehost.restivo.me/key.pem'';*/
         SupplementaryGroups = [ config.users.groups.keys.name config.users.groups.nginx.name ];
       };
   };
  };
}

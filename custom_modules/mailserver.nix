{ config, pkgs, lib, ... }:
let
  cfg = config.custom_modules.mailserver;
  fqdn = "mail.restivo.me";
  server-ip = "150.136.52.94";
  domains = [ "restivo.me" ];
in
{
  options.custom_modules.mailserver.enable =
    lib.mkOption {
      description = "Enable Mail Server";
      type = lib.types.bool;
      default = false;
    };
  config = lib.mkIf cfg.enable {
    security.acme = {
      acceptTerms = true;
      # Replace the email here!
      email = "justin.p.restivo@gmail.com";
    };
    mailserver = {
      enable = true;
      fqdn = fqdn;
      domains = domains;

      loginAccounts = {
        "justin@restivo.me" = {
          hashedPasswordFile = config.sops.secrets.hashed_email_password.path;
          aliases = [ "postmaster@restivo.me" ];

          catchAll = domains;
        };
      };

      certificateScheme = 3;
      enableImap = true;
      enablePop3 = true;
      enableImapSsl = true;
      enablePop3Ssl = true;
      enableManageSieve = true;
      virusScanning = true;


    };
  };
}

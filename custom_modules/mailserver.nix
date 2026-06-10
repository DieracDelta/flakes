{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.mailserver;
  domain = "ironmain.dev";
  fqdn = "mail.${domain}";
  acmeWebroot = "/var/lib/acme-challenges/${fqdn}";
  smtp2goSaslPasswd = "/var/lib/ironmain-mail/sasl_passwd";
in
{
  options.custom_modules.mailserver.enable = lib.mkEnableOption "IronMain self-hosted mail server";

  config = lib.mkIf cfg.enable {
    security.acme = {
      acceptTerms = true;
      defaults.email = "justin@ironmain.dev";
      certs.${fqdn} = {
        webroot = acmeWebroot;
        group = "acme";
        reloadServices = [
          "postfix.service"
          "dovecot.service"
        ];
      };
    };

    users.groups.acme = { };
    users.users.acme = {
      isSystemUser = true;
      group = "acme";
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/ironmain-mail 0700 root root -"
      "d /var/lib/acme-challenges 0755 root root -"
      "d ${acmeWebroot} 0755 acme caddy -"
      "z ${acmeWebroot} 0755 acme caddy -"
      "d ${acmeWebroot}/.well-known 0755 acme caddy -"
      "z ${acmeWebroot}/.well-known 0755 acme caddy -"
      "d ${acmeWebroot}/.well-known/acme-challenge 0755 acme caddy -"
      "z ${acmeWebroot}/.well-known/acme-challenge 0755 acme caddy -"
    ];

    services.caddy.virtualHosts."http://${fqdn}" = {
      extraConfig = ''
        bind 10.0.1.206
        root * ${acmeWebroot}
        file_server
      '';
    };

    mailserver = {
      enable = true;
      stateVersion = 3;
      inherit fqdn;
      domains = [ domain ];

      x509.useACMEHost = fqdn;

      enableImap = false;
      enableImapSsl = true;
      enablePop3 = false;
      enablePop3Ssl = false;
      enableSubmission = true;
      enableSubmissionSsl = true;
      enableManageSieve = false;

      localDnsResolver = false;
      virusScanning = false;
      dkim.enable = false;

      accounts."justin@ironmain.dev" = {
        hashedPasswordFile = "/var/lib/ironmain-mail/justin.hashed-password";
        aliases = [
          "admin@ironmain.dev"
          "abuse@ironmain.dev"
          "postmaster@ironmain.dev"
        ];
        quota = "5G";
      };
    };

    services.postfix.settings.main = {
      relayhost = [ "[mail.smtp2go.com]:587" ];
      smtp_sasl_auth_enable = "yes";
      smtp_sasl_password_maps = "hash:${smtp2goSaslPasswd}";
      smtp_sasl_security_options = "noanonymous";
      smtp_sasl_tls_security_options = "noanonymous";
      smtp_tls_CAfile = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      smtp_tls_security_level = lib.mkForce "encrypt";
    };

    systemd.services.postfix.preStart = lib.mkAfter ''
      if [ ! -s ${smtp2goSaslPasswd} ]; then
        echo "Missing ${smtp2goSaslPasswd}; expected: [mail.smtp2go.com]:587 USERNAME:PASSWORD" >&2
        exit 1
      fi
      ${config.services.postfix.package}/sbin/postmap ${smtp2goSaslPasswd}
    '';
  };
}

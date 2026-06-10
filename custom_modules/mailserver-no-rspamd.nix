{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  disabledModules = [
    "${inputs.simple-nixos-mailserver}/mail-server/environment.nix"
    "${inputs.simple-nixos-mailserver}/mail-server/rspamd.nix"
  ];

  config = lib.mkIf config.mailserver.enable {
    environment.systemPackages = [
      config.services.dovecot2.package
      pkgs.openssh
      config.services.postfix.package
    ];

    services.postfix.settings.main = {
      smtpd_milters = lib.mkForce [ ];
      non_smtpd_milters = lib.mkForce [ ];
    };

    services.dovecot2.sieve.pipeBins = lib.mkForce [ ];
  };
}

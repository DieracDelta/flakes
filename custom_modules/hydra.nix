{ config, pkgs, lib, ... }:
let
  cfg = config.custom_modules.hydra;
in {
  options.custom_modules.hydra.enable =
    lib.mkOption {
      description = "Enable Hydra";
      type = lib.types.bool;
      default = false;
    };
  config = lib.mkIf cfg.enable {
    services.hydra = {
      package = pkgs.hydra-unstable;
      enable = true;
      hydraURL = "https://localhost:3000"; # externally visible URL
      notificationSender = "hydra@localhost"; # e-mail of hydra service
      # a standalone hydra will require you to unset the buildMachinesFiles list to avoid using a nonexistant /etc/nix/machines
      buildMachinesFiles = [];
      # you will probably also want, otherwise *everything* will be built from scratch
      useSubstitutes = true;
    };
    networking.firewall.allowedUDPPorts = [ 3000 ];
    networking.firewall.allowedTCPPorts = [ 3000 ];

    services.gitlab = {
      enable = true;
      initialRootPasswordFile = "${config.sops.secrets.gitlab_password.path}";
      secrets = {
        secretFile = "${config.sops.secrets.gitlab_password.path}";
        dbFile = "${config.sops.secrets.gitlab_password.path}";
        otpFile = "${config.sops.secrets.gitlab_password.path}";
        jwsFile = "${config.sops.secrets.gitlab_password.path}";
      };
    };
    services.gitlab-runner.enable = true;


  };
}

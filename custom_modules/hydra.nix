{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.hydra;
in
{
  options.custom_modules.hydra.enable = lib.mkOption {
    description = "Enable Hydra CI";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    services.hydra = {
      enable = true;
      hydraURL = "https://office-desktop.tail5ca7.ts.net/hydra";
      notificationSender = "hydra@localhost";
      buildMachinesFiles = [ ];
      useSubstitutes = true;
      listenHost = "127.0.0.1";
      port = 3009;
      extraConfig = ''
        using_frontend_proxy 1
        allow_import_from_derivation = true
      '';
    };

    nix.settings.trusted-users = [
      "hydra"
      "hydra-queue-runner"
      "hydra-www"
    ];
    nix.settings.allowed-users = [
      "hydra"
      "hydra-queue-runner"
      "hydra-www"
    ];
    nix.settings.allow-import-from-derivation = true;

    nix.settings.allowed-uris = [
      # GitHub
      "github:"
      "git+https://github.com/"
      "git+ssh://git@github.com/"
      "https://github.com/"

      # GitLab
      "gitlab:"
      "git+https://gitlab.com/"
      "git+ssh://git@gitlab.com/"
      "https://gitlab.com/"

      # Sourcehut
      "sourcehut:"
      "git+https://git.sr.ht/"
      "git+ssh://git@git.sr.ht/"
      "https://git.sr.ht/"

      # Codeberg
      "git+https://codeberg.org/"
      "https://codeberg.org/"

      # NixOS resources
      "https://nixos.org/"
      "https://cache.nixos.org/"
      "https://channels.nixos.org/"
      "https://releases.nixos.org/"

      # Flake registries
      "https://api.flakehub.com/"

      # Common source tarballs
      "https://static.rust-lang.org/"
      "https://crates.io/"
      "https://registry.npmjs.org/"
      "https://pypi.org/"
      "https://files.pythonhosted.org/"
    ];

    networking.firewall.allowedTCPPorts = [ 3009 ];
  };
}

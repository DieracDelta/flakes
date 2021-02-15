{ config, pkgs, lib, options, system, builtins, ... }:
/*TODO read these in from secrets.yaml by parsing yaml file*/
/*TODO fix naming inconsistency*/
let secrets = [
                "desktop_public_key"
                "laptop_public_key"
                "desktop_private_key"
                "laptop_private_key"
                "zerotier_key"
                "rust_filehost_secrets"
              ];
    genDefaultPerms = secret: {
      ${secret} = {
        mode = "0440";
        owner = config.users.users.jrestivo.name;
        group = config.users.users.jrestivo.group;
      };
    };
    cfg = config.custom_modules.core_services;
in
{
  options.custom_modules.core_services.enable =
    lib.mkOption {
      description = ''
        Core services to be enabled on everything. Includes secrets, ssh, zerotier, tailscale, firewall, etc. Also sets up users, ssh keys, internet, nix cache.
      '';
      type = lib.types.bool;
      default = true;
    };

  config = lib.mkIf cfg.enable {
    /*TODO pass in global root state to create path from*/
    sops.defaultSopsFile = ../secrets/secrets.yaml;
    sops.secrets = (((lib.foldl' lib.mergeAttrs) {}) (builtins.map genDefaultPerms secrets))
      //   {tailscale_key.owner = "root"; };


    # OP ssh between all the devices
    services.zerotierone.enable = true;
    # TODO move this to a secret
    services.zerotierone.joinNetworks = [ "af415e486feddf70" ];

    # even more OP ssh between all the devices
    services.tailscale = {
      enable = true;
    };
     # create a oneshot job to authenticate to Tailscale
    systemd.services.tailscale-autoconnect = {
      description = "Automatic authentication to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = [ "network-pre.target" "tailscale.service" ];
      wants = [ "network-pre.target" "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];

      # set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      # have the job run this shell script
      script = with pkgs; ''
        # wait for tailscaled to settle
        sleep 2

        # check if we are already authenticated to tailscale
        status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
        if [ $status = "Running" ]; then # if so, then do nothing
          exit 0
        fi

        # otherwise authenticate with tailscale
        ${tailscale}/bin/tailscale up -authkey "$(cat ${config.sops.secrets.tailscale_key.path})"
      '';
      serviceConfig.SupplementaryGroups = [ config.users.groups.keys.name ];
    };

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
    };
    programs.ssh = {
      forwardX11 = true;
      setXAuthLocation = true;
    };

    networking.firewall.allowedTCPPorts = [ 3389 80 443 444 9993];

    services.lorri.enable = true;

    services.gnome3.gnome-keyring.enable = true;

    services.locate = {
      enable = true;
      locate = pkgs.unstable.mlocate;
      localuser = null; # mlocate does not support this option so it must be null
      interval = "weekly";
      pruneNames = [
        ".git"
          "cache"
          ".cache"
          ".cpcache"
          ".aot_cache"
          ".boot"
          "node_modules"
          "USB"
      ];
      prunePaths = options.services.locate.prunePaths.default ++ [
        "/dev"
        "/lost+found"
        "/nix/var"
        "/proc"
        "/run"
        "/sys"
        "/usr/tmp"
      ];
    };

    users.users = {
      jrestivo = {
        isNormalUser = true;
        home = "/home/jrestivo";
        shell = pkgs.zsh;
        description = "Justin --the owner-- Restivo";
        extraGroups =
          [ "wheel" "networkmanager" "audio" "input" "docker" "adbusers" "jackaudio" "keys"];
        initialPassword = "bruh";
      };
    };
    # environment.etc = { };

    networking.useDHCP = false;
    networking.networkmanager.enable = true;

    time.timeZone = "America/New_York";
    location.provider = "geoclue2";

    system.stateVersion = "20.09";

    environment.variables = {
      BROWSER = "firefox";
      EDITOR = "nvim";
    };

    users.users.jrestivo.openssh.authorizedKeys.keys = [
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnVsxxx7yiI1yWh2+wkmH7jMDTfvypsLfVkYuz+WObIi3V+1gZN3cPjHFYwEa1SpUNSs4/c2zdM1CANR5b61YgBmvbxYUVCBFNSeO1B9JTPUDcyM20vhRdeUOFlPS0KJHkKnlzjq4sEnjDM+zXCtAKEekBRcWqcnK2WX/Q9CI6+ocaJ30r06T0Hqa4C7Gx6pNbVNxaTaza3Mzod68aBjyg7WShsKPF5nLSe9QJIjUQ2bjGdRCUlXshgmW+E127KqryZqYLmmodF9fynCK6Ne+MDM2jEruRHMwhv50MfnO0ntOOM0i37oR3JuKE+AzJj/+Ete/YVbbIxipMm0DkNJEEqFsZRO5qkiP2MpI4TCZxHaac/pl+W6HdhwzSKCUrVBUTwEacaz/3WFgGgTjebpW1hfYbcTalG6e9t2W0OSg+INYLklp4uHDWHjFqyl5J+FZMNQdtWgD3yRyZN9rf1ojVf5AgxSW6pXIcrqMf/6Kf+kr/O0FOakrLaEHTDmONVTM= justin.p.restivo@gmail.com
      ''
    ];
    users.users.root.openssh.authorizedKeys.keys = [
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnVsxxx7yiI1yWh2+wkmH7jMDTfvypsLfVkYuz+WObIi3V+1gZN3cPjHFYwEa1SpUNSs4/c2zdM1CANR5b61YgBmvbxYUVCBFNSeO1B9JTPUDcyM20vhRdeUOFlPS0KJHkKnlzjq4sEnjDM+zXCtAKEekBRcWqcnK2WX/Q9CI6+ocaJ30r06T0Hqa4C7Gx6pNbVNxaTaza3Mzod68aBjyg7WShsKPF5nLSe9QJIjUQ2bjGdRCUlXshgmW+E127KqryZqYLmmodF9fynCK6Ne+MDM2jEruRHMwhv50MfnO0ntOOM0i37oR3JuKE+AzJj/+Ete/YVbbIxipMm0DkNJEEqFsZRO5qkiP2MpI4TCZxHaac/pl+W6HdhwzSKCUrVBUTwEacaz/3WFgGgTjebpW1hfYbcTalG6e9t2W0OSg+INYLklp4uHDWHjFqyl5J+FZMNQdtWgD3yRyZN9rf1ojVf5AgxSW6pXIcrqMf/6Kf+kr/O0FOakrLaEHTDmONVTM= justin.p.restivo@gmail.com
      ''
    ];

    nix = {
      /*warn-dirty = true;*/
      extraOptions = ''
      gc-keep-outputs = true
      warn-dirty = false
      '';

      # cachix stuffs
      binaryCaches = [
        "https://cache.nixos.org"
        "https://cachix.cachix.org"
        "https://gytix.cachix.org/"
        "https://jrestivo.cachix.org"
        "http://nix-community.cachix.org/"
      ];
      binaryCachePublicKeys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
        "gytix.cachix.org-1:JXNZBxYslCV/hAkfNvJgyxlWb8jRQRKc+M0h7AaFg7Y="
        "jrestivo.cachix.org-1:+jSOsXAAOEjs+DLkybZGQEEIbPG7gsKW1hPwseu03OE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    # to get zsh autocomplete to work
    environment.pathsToLink = [ "/share/zsh" ];
    /*ONLY cli stuff*/
    environment.systemPackages = with pkgs; [
      deploy-rs
      ytop
      direnv
      git
      tigervnc
      evemu
      xdg_utils
      dnsutils
      hwloc
      ngrok
      nix-search-pretty
      gnupg
      ssh-to-pgp
      lsof
      nox
      nix-top
      nix-du
      nixpkgs-fmt
      zsh-forgit
      procs
      exa
      nixos-generators
      evtest
      unzip
      nix-tree
      nixFlakes
      fzf
      cachix
      bat
      manix
      zsh
      ripgrep
      neofetch
      tmux
      fasd
      jq
      mosh
      pstree
      tree
      ranger
      nix-index
      file
      hunter
      neovim-nightly
      fd
      sd
      tealdeer
      dnsutils
      mkpasswd
      htop
      wget
      ispell
    ];

    programs.mosh.enable = true;
  };
}

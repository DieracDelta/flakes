{ config, pkgs, lib, options, system, ... }:
/*TODO read these in from secrets.yaml by parsing yaml file*/
/*TODO fix naming inconsistency*/
let
  secrets = [
    "zerotier_key"
    "rust_filehost_secrets"
    "rust_filehost_secret_key"
    "email_password"
    "hashed_email_password"
    "gitlab_password"
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
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    networking.nameservers = [ "100.100.100.100" "1.1.1.1" ];
    /*TODO pass in global root state to create path from*/
    sops.defaultSopsFile = ../secrets/secrets.yaml;
    sops.secrets = (((lib.foldl' lib.mergeAttrs) { }) (builtins.map genDefaultPerms secrets))
      // { tailscale_key.owner = "root"; };


    # OP ssh between all the devices
    # services.zerotierone.enable = true;
    # TODO move this to a secret
    # services.zerotierone.joinNetworks = [ "af415e486feddf70" ];

    # even more OP ssh between all the devices
    services.tailscale = {
      enable = true;
    };
    # create a oneshot job to authenticate to Tailscale
    /*systemd.services.tailscale-autoconnect = {*/
      /*description = "Automatic authentication to Tailscale";*/

      /*# make sure tailscale is running before trying to connect to tailscale*/
      /*after = [ "network-pre.target" "tailscale.service" ];*/
      /*wants = [ "network-pre.target" "tailscale.service" ];*/
      /*wantedBy = [ "multi-user.target" ];*/

      /*# set this service as a oneshot job*/
      /*serviceConfig.Type = "oneshot";*/

      /*# have the job run this shell script*/
      /*script = with pkgs; ''*/
        /*# wait for tailscaled to settle*/
        /*sleep 2*/

        /*# check if we are already authenticated to tailscale*/
        /*status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"*/
        /*if [[ "$status" == "Running" ]]; then*/
          /*exit 0*/
        /*fi*/

        /*# otherwise authenticate with tailscale*/
        /*${tailscale}/bin/tailscale up -authkey "$(cat ${config.sops.secrets.tailscale_key.path})"*/
      /*'';*/
      /*serviceConfig.SupplementaryGroups = [ config.users.groups.keys.name ];*/
    /*};*/

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
    };
    programs.ssh = {
      forwardX11 = true;
      setXAuthLocation = true;
    };

    networking.firewall.allowedTCPPorts = [ 3389 80 443 444 9993 ];

    services.lorri.enable = true;

    services.gnome.gnome-keyring.enable = true;

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
          [ "wheel" "networkmanager" "audio" "input" "docker" "adbusers" "jackaudio" "keys" "plugdev" "trezord" ];
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
      BROWSER = "chromium";
      EDITOR = "nvim";
    };

    users.users.jrestivo.openssh.authorizedKeys.keys = [
      #laptop
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5qlN93RBt99GVy6YDP3OMb7Yu4zwELvT5kvdTRnPzE9txmdxKiMM8eHGw4vBwcbmwY7y1wa+ijXwiT0PbwDUOQvVu8CzWHxBF0pz8LVy7XsBuQr9UtxXVV6D9KBKJJEQjpKgF0LTGOC3LSdHKqlH/4zUaUpE2ZPOaoS01S8YwNfRbr30XDeilMDD5rY0AVlydKFRZIbf/96fdo4HURKcjRMapTdYrdkj++FINCl4IDOId3UQR7Z8qDmx2IC6rOikMNMGwEFvgueCDHDuieqNfHn9LVv8gzCPZ0QtX5Ap+6FPNiUfBXuG1IK7RzeDicGUSXWfKFQImwo6pppArqvtqizEFY6WDBSso5XTveg3Z/gH5/jfMigElVAh8xob/NAW2lv6lHEjXtFVmk3N2Fz425SfXQp2qyaYOPGYohWt1ZwlMdkHYfYGtskaoUd9XCM3GC+aSSLkMPuaXtLS3aJ9R7jcz4sfXdU0s3Vd+jQl7c9n3lGYlZ59aKruUj50QtAs= jrestivo@jrestivo.local
      ''
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnVsxxx7yiI1yWh2+wkmH7jMDTfvypsLfVkYuz+WObIi3V+1gZN3cPjHFYwEa1SpUNSs4/c2zdM1CANR5b61YgBmvbxYUVCBFNSeO1B9JTPUDcyM20vhRdeUOFlPS0KJHkKnlzjq4sEnjDM+zXCtAKEekBRcWqcnK2WX/Q9CI6+ocaJ30r06T0Hqa4C7Gx6pNbVNxaTaza3Mzod68aBjyg7WShsKPF5nLSe9QJIjUQ2bjGdRCUlXshgmW+E127KqryZqYLmmodF9fynCK6Ne+MDM2jEruRHMwhv50MfnO0ntOOM0i37oR3JuKE+AzJj/+Ete/YVbbIxipMm0DkNJEEqFsZRO5qkiP2MpI4TCZxHaac/pl+W6HdhwzSKCUrVBUTwEacaz/3WFgGgTjebpW1hfYbcTalG6e9t2W0OSg+INYLklp4uHDWHjFqyl5J+FZMNQdtWgD3yRyZN9rf1ojVf5AgxSW6pXIcrqMf/6Kf+kr/O0FOakrLaEHTDmONVTM= justin.p.restivo@gmail.com
      ''
      # MOST RECENT
      ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5DtmAk4jcG0i0m1HCnhienAMUgBQ25Srs5P9pRe1eL openpgp:0x1CE431A7
      ''
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpGFCfG6Yq+CaAqNZcU41FhGv5JcLehkUa59eaw35iM openpgp:0x16CE5BD0
      ''
      # jared
      ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID26MAsR89ZknXksgR5S4x2c9HZy1db/ioFqiXllaGpU jarednathanielrestivo@Laptop-2.local
      ''
    ];
    users.users.root.openssh.authorizedKeys.keys = [
      #laptop
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5qlN93RBt99GVy6YDP3OMb7Yu4zwELvT5kvdTRnPzE9txmdxKiMM8eHGw4vBwcbmwY7y1wa+ijXwiT0PbwDUOQvVu8CzWHxBF0pz8LVy7XsBuQr9UtxXVV6D9KBKJJEQjpKgF0LTGOC3LSdHKqlH/4zUaUpE2ZPOaoS01S8YwNfRbr30XDeilMDD5rY0AVlydKFRZIbf/96fdo4HURKcjRMapTdYrdkj++FINCl4IDOId3UQR7Z8qDmx2IC6rOikMNMGwEFvgueCDHDuieqNfHn9LVv8gzCPZ0QtX5Ap+6FPNiUfBXuG1IK7RzeDicGUSXWfKFQImwo6pppArqvtqizEFY6WDBSso5XTveg3Z/gH5/jfMigElVAh8xob/NAW2lv6lHEjXtFVmk3N2Fz425SfXQp2qyaYOPGYohWt1ZwlMdkHYfYGtskaoUd9XCM3GC+aSSLkMPuaXtLS3aJ9R7jcz4sfXdU0s3Vd+jQl7c9n3lGYlZ59aKruUj50QtAs= jrestivo@jrestivo.local
      ''
      # MOST RECENT
      ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5DtmAk4jcG0i0m1HCnhienAMUgBQ25Srs5P9pRe1eL openpgp:0x1CE431A7
      ''
      ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnVsxxx7yiI1yWh2+wkmH7jMDTfvypsLfVkYuz+WObIi3V+1gZN3cPjHFYwEa1SpUNSs4/c2zdM1CANR5b61YgBmvbxYUVCBFNSeO1B9JTPUDcyM20vhRdeUOFlPS0KJHkKnlzjq4sEnjDM+zXCtAKEekBRcWqcnK2WX/Q9CI6+ocaJ30r06T0Hqa4C7Gx6pNbVNxaTaza3Mzod68aBjyg7WShsKPF5nLSe9QJIjUQ2bjGdRCUlXshgmW+E127KqryZqYLmmodF9fynCK6Ne+MDM2jEruRHMwhv50MfnO0ntOOM0i37oR3JuKE+AzJj/+Ete/YVbbIxipMm0DkNJEEqFsZRO5qkiP2MpI4TCZxHaac/pl+W6HdhwzSKCUrVBUTwEacaz/3WFgGgTjebpW1hfYbcTalG6e9t2W0OSg+INYLklp4uHDWHjFqyl5J+FZMNQdtWgD3yRyZN9rf1ojVf5AgxSW6pXIcrqMf/6Kf+kr/O0FOakrLaEHTDmONVTM= justin.p.restivo@gmail.com
      ''
      # MOST RECENT
      ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpGFCfG6Yq+CaAqNZcU41FhGv5JcLehkUa59eaw35iM openpgp:0x16CE5BD0
      ''

    ];

    nix = {
      binaryCaches = [
        "https://jrestivo.cachix.org"
      ];
      binaryCachePublicKeys = [
        "jrestivo.cachix.org-1:+jSOsXAAOEjs+DLkybZGQEEIbPG7gsKW1hPwseu03OE="
      ];

      /*warn-dirty = true;*/
      extraOptions = ''
        gc-keep-outputs = true
        warn-dirty = false
        experimental-features = nix-command flakes
        extra-platforms = x86_64-linux i686-linux aarch64-linux armv7l-linux riscv64-linux
        sandbox-dev-shm-size = 5%
        '';

# cachix stuffs
      settings.substituters = [
        "https://cache.nixos.org"
          "https://cachix.cachix.org"
          "https://gytix.cachix.org/"
          "https://jrestivo.cachix.org"
          "http://nix-community.cachix.org/"
      ];
      settings.trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
          "gytix.cachix.org-1:JXNZBxYslCV/hAkfNvJgyxlWb8jRQRKc+M0h7AaFg7Y="
          "jrestivo.cachix.org-1:+jSOsXAAOEjs+DLkybZGQEEIbPG7gsKW1hPwseu03OE="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d --max-freed $((64 * 1024**3))";
      };
      optimise = {
        automatic = true;
        dates = [ "weekly" ];
      };
    };

    # to get zsh autocomplete to work
    environment.pathsToLink = [ "/share/zsh" ];
    /*ONLY cli stuff*/
    environment.systemPackages = with pkgs; [
      dmidecode
      deploy-rs
      bottom
      direnv
      git
      tigervnc
      evemu
      xdg_utils
      dnsutils
      # NOTE: brocken apparently
      # hwloc
      ngrok
      gnupg
      ssh-to-pgp
      lsof
      nox
      nix-top
      nix-du
      nixpkgs-fmt
      #zsh-forgit
      # procs
      eza
      nixos-generators
      evtest
      unzip
      nix-tree
      nixFlakes
      fzf
      # cachix
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
      fd
      sd
      tealdeer
      dnsutils
      mkpasswd
      htop
      wget
      ispell
      whois
    ];

    programs.mosh.enable = true;
  };
}

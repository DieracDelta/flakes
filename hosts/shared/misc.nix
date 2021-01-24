{ config, pkgs, lib, ... }:

{

  users.users.jrestivo = {
    isNormalUser = true;
    home = "/home/jrestivo";
    shell = pkgs.zsh;
    description = "Justin --the owner-- Restivo";
    extraGroups =
      [ "wheel" "networkmanager" "audio" "input" "docker" "adbusers" "jackaudio" ];
    initialPassword = "bruh";
  };

  networking.useDHCP = false;
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";
  location.provider = "geoclue2";

  system.stateVersion = "20.09";

  environment.variables = {
    BROWSER = "firefox";
    EDITOR = "nvim";
  };

  users.users.jrestivo.openssh.authorizedKeys.keys = [''
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnVsxxx7yiI1yWh2+wkmH7jMDTfvypsLfVkYuz+WObIi3V+1gZN3cPjHFYwEa1SpUNSs4/c2zdM1CANR5b61YgBmvbxYUVCBFNSeO1B9JTPUDcyM20vhRdeUOFlPS0KJHkKnlzjq4sEnjDM+zXCtAKEekBRcWqcnK2WX/Q9CI6+ocaJ30r06T0Hqa4C7Gx6pNbVNxaTaza3Mzod68aBjyg7WShsKPF5nLSe9QJIjUQ2bjGdRCUlXshgmW+E127KqryZqYLmmodF9fynCK6Ne+MDM2jEruRHMwhv50MfnO0ntOOM0i37oR3JuKE+AzJj/+Ete/YVbbIxipMm0DkNJEEqFsZRO5qkiP2MpI4TCZxHaac/pl+W6HdhwzSKCUrVBUTwEacaz/3WFgGgTjebpW1hfYbcTalG6e9t2W0OSg+INYLklp4uHDWHjFqyl5J+FZMNQdtWgD3yRyZN9rf1ojVf5AgxSW6pXIcrqMf/6Kf+kr/O0FOakrLaEHTDmONVTM= justin.p.restivo@gmail.com
  ''];

  # cachix stuffs
  nix = {
    extraOptions = "gc-keep-outputs = true";

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

  # environment.etc = { };
}

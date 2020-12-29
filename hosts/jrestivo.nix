{ config, pkgs, lib, ... }:

{

  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./configuration.nix ./shared ./hw/laptop.nix ];
}

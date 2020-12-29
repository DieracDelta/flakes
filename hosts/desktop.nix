{ config, pkgs, lib, ... }:

{

  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./shared ./hw/desktop.nix ];
}

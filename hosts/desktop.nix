{ config, pkgs, lib, ... }:

{

  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./shared ./hw/desktop.nix ../custom_modules/nextcloud.nix ];
  /*imports = [ ./shared ./hw/desktop.nix ];*/
}

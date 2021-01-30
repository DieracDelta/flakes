{ config, pkgs, lib, ... }:

{

  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./shared ./hw/desktop.nix ../custom_modules/nextcloud.nix ../custom_modules/jellyfin.nix ];
  /*imports = [ ./shared ./hw/desktop.nix ];*/
}

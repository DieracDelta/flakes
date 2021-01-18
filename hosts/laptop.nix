{ config, pkgs, lib, pkgset, ... }:

{

  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./shared ./hw/laptop.nix ];


}

{ config, pkgs, lib, ... }:

{

  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./shared ./hw/laptop.nix ];


}

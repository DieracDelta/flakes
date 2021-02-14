{config, pkgs, lib, ...}:

{
  nix.allowedUsers = [ "jrestivo" ];
  imports = [ ./hw/oracle_vps.nix ];
}

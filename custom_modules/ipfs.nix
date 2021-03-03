{ config, pkgs, lib, ... }:
let
  cfg = config.custom_modules.ipfs;
in {
  /*options.custom_modules.ipfs.enable =*/
    /*lib.mkOption {*/
      /*description = "Back up Mail with ipfs";*/
      /*type = lib.types.bool;*/
      /*default = true;*/
    /*};*/
  /*config = lib.mkIf cfg.enable {*/
  services.ipfs.enable = true;
  /*};*/
}

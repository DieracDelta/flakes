{ config, pkgs, lib, ... }:
let
  cfg = config.custom_modules.ipfs;
in {
  options.custom_modules.ipfs.enable =
    lib.mkOption {
      description = "Back up stuff with ipfs";
      type = lib.types.bool;
      default = true;
    };
  config = lib.mkIf cfg.enable {
    #services.ipfs.enable = true;
    #environment.systemPackages = with pkgs; [
      #pkgs.ipfs-cluster
    #];
#   ipfs init || true
#   ID=$(ipfs id | jq -r ".ID")
 };
}

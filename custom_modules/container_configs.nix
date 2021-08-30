{ config, pkgs, lib, ... }:
let
  cfg = config.custom_modules.container_configs;
in
{
  options.custom_modules.container_configs.enable = lib.mkEnableOption "Enable nixos contianers";
  config = lib.mkIf cfg.enable {
    containers.database = {
      privateNetwork = true;
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      config =
        { config, pkgs, ... }:
        {
          services.postgresql = {
            enable = true;
            package = pkgs.postgresql_13;
            enableTCPIP = true;
            authentication = pkgs.lib.mkOverride 10 ''
             local all all trust
             host all all ::1/128 trust
            '';
            initialScript = pkgs.writeText "backend-initScript" ''
             CREATE ROLE nixcloud WITH LOGIN PASSWORD 'nixcloud' CREATEDB;
             CREATE DATABASE nixcloud;
             GRANT ALL PRIVILEGES ON DATABASE nixcloud TO nixcloud;
            '';
          };
        };
    };
  };
}

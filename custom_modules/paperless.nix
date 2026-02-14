{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.paperless;
in
{
  options.custom_modules.paperless.enable = lib.mkOption {
    description = "Enable Paperless-ngx document management.";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;
      # passwordFile = "/etc/paperless-admin-pass";
      port = 28981;
      # dataDir = "/var/lib/paperless";
      # mediaDir = "/var/lib/paperless/media";
      # consumptionDir = "/var/lib/paperless/in";
      # consumptionDirIsPublic = true;
      address = "0.0.0.0";
      settings = {
        # 1. This is the Magic Switch: Tells Paperless "I live in this folder"
        PAPERLESS_FORCE_SCRIPT_NAME = "/paperless";
        PAPERLESS_STATIC_URL = "/paperless/static/";

        # 2. Your full public URL (Must include /paperless at the end)
        PAPERLESS_URL = "https://office-desktop.tail5ca7.ts.net";

        # 3. Security settings to allow the connection
        PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://office-desktop.tail5ca7.ts.net";
        PAPERLESS_CORS_ALLOWED_ORIGINS = "https://office-desktop.tail5ca7.ts.net";
        PAPERLESS_ALLOWED_HOSTS = "office-desktop.tail5ca7.ts.net,localhost,127.0.0.1";
        PAPERLESS_DISABLE_REGULAR_LOGIN = true;
        PAPERLESS_ENABLE_HTTP_REMOTE_USER = true;
      };
    };
    users.users.paperless = {
      shell = pkgs.bashInteractive;
      isSystemUser = true;
    };

    networking.firewall.allowedTCPPorts = [ 28981 ];
    networking.firewall.allowedUDPPorts = [ 28981 ];
  };
}

{
  config,
  pkgs,
  lib,
  inputs,
  system,
  ...
}:
let
  cfg = config.custom_modules.comfyui;
in
{
  options.custom_modules.comfyui.enable = lib.mkOption {
    description = "Enable comfy ui";
    type = lib.types.bool;
    default = true;

  };
  config = lib.mkIf cfg.enable {
    services.comfyui = {
      enable = true;
      cuda = true;
      enableManager = true;
      port = 6188;
      listenAddress = "0.0.0.0";
      dataDir = "/var/lib/comfyui";
      openFirewall = true;
      # extraArgs = [ "--lowvram" ];
      # environment = { };
    };
    services.gonic = {
      enable = true;
      settings = {
        music-path = [ "/var/lib/gonic/example_music" ];
        listen-addr = "0.0.0.0:4747";
        cache-path = "/var/cache/gonic";
        podcast-path = "/var/lib/gonic/podcasts";
        playlists-path = "/var/lib/gonic/playlists";
        proxy-prefix = "/gonic";
      };
    };
    systemd.services.gonic.serviceConfig = {
      SupplementaryGroups = [ "users" ];
      ProtectHome = lib.mkForce "read-only";
      ReadWritePaths = [
        "/var/cache/gonic"
        "/var/lib/gonic"
      ];
      ProtectSystem = "full";
      NoNewPrivileges = true;
    };
    # THIS DIDNT WORK AT ALL AND LOCKED ME TF OUT
    # systemd.services.tailscaled-sidecar = {
    #   description = "Temporary Tailscale sidecar for Apple Review";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     # --tun=user runs in userspace (no conflict with your main tailscale0 interface)
    #     # --socket and --statedir keep it isolated from your main config
    #     ExecStart = "${pkgs.tailscale}/bin/tailscaled --statedir=/var/lib/tailscale/sidecar --socket=/run/tailscale/sidecar.socket --port=0 --tun=user";
    #     Restart = "on-failure";
    #   };
    # };

  };

}

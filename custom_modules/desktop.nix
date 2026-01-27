# Desktop environment configuration
# Plasma, i3, display managers, picom, fonts
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.desktop;
in
{
  options.custom_modules.desktop.enable = lib.mkOption {
    description = "Enable desktop environment (Plasma, i3, display managers)";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    # Plasma 6
    environment.plasma6.excludePackages = [
      pkgs.kdePackages.baloo
      pkgs.kdePackages.spectacle
      pkgs.kdePackages.kate
    ];
    services.desktopManager.plasma6.enable = true;
    services.libinput.enable = true;
    services.displayManager.sddm.enable = true;
    services.xserver.displayManager.sessionCommands = ''
      systemctl --user start graphical-session.target
    '';

    # X server with i3 fallback
    services.xserver = {
      enable = true;
      xkb.layout = "us";
      windowManager.i3 = {
        enable = true;
        package = pkgs.i3;
        extraPackages = with pkgs; [ rofi ];
      };
    };

    # Compositor
    services.picom.enable = true;

    # Plymouth boot splash
    boot.plymouth.enable = true;

    # Fonts
    fonts.packages = with pkgs; [
      d2coding
      nerd-fonts.fira-code
      fira-code
      fira-code-symbols
    ];

    # Desktop programs
    programs.dconf.enable = true;

    # xRDP for remote desktop
    services.xrdp.enable = true;

    networking.firewall.allowedTCPPorts = [
      3389  # RDP
    ];
  };
}

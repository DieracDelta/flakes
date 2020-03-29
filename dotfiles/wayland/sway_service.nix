{ config, pkgs, lib, ... }:
{

  programs.sway = {
    enable = true;
    extraPackages = with pkgs; [
      swaylock # lockscreen
        swayidle
        xwayland # for legacy apps

    ];
  };

  systemd.services.ly_dup = {
    description = "TUI display manager";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "idle";
      ExecStart = "${pkgs.ly}/bin/ly";
      StandardInput = "tty";
      TTYPath = "/dev/tty2";
      TTYReset = "yes";
      TTYVHangup = "yes";
    };
  };
  systemd.services.ly_dp.enable = true;
}


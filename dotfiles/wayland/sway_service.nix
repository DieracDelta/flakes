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

  systemd.user.targets.sway-session = {
    description = "Sway compositor session";
    documentation = [ "man:systemd.special(7)" ];
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };
  systemd.user.services.sway = {
    description = "Sway - Wayland window manager";
    documentation = [ "man:sway(5)" ];
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
# We explicitly unset PATH here, as we want it to be set by
# systemctl --user import-environment in startsway
    environment.PATH = lib.mkForce null;
    serviceConfig = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.dbus}/bin/dbus-run-session ${pkgs.sway}/bin/sway --debug
        '';
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
  /*both of these are broken : (*/
  /*systemd.units."ly_dup_2.service".text = ''*/
  /*[Unit]*/
  /*Description=TUI display manager*/
  /*After=systemd-user-sessions.service plymouth-quit-wait.service*/
  /*After=getty@tty2.service*/

  /*[Service]*/
  /*Type=idle*/
  /*ExecStart=${pkgs.ly}/bin/ly*/
  /*StandardInput=tty*/
  /*TTYPath=/dev/tty5*/
  /*TTYReset=yes*/
  /*TTYVHangup=yes*/

  /*[Install]*/
  /*Alias=display-manager.service*/
  /*'';*/
  /*systemd.services.ly_dup = {*/
  /*description = "TUI display manager";*/
  /*after = ["systemd-user-sessions.service" "plymouth-quit-wait.service" "getty@tty2.service"];*/
  /*serviceConfig = {*/
  /*Type = "idle";*/
  /*ExecStart = "${pkgs.ly}/bin/ly";*/
  /*StandardInput = "tty";*/
  /*TTYPath = "/dev/tty2";*/
  /*TTYReset = "yes";*/
  /*TTYVHangup = "yes";*/
  /*};*/
  /*};*/
}


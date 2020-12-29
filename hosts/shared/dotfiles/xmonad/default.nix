{ pkgs, ... }:
let extraPackages = import ./extraPackages.nix;
in {
  /*imports = [ ../polybar.nix ../dunst.nix ../picom.nix ];*/
  /*home.packages = with pkgs; [ gnome3.zenity ];*/
  xsession.windowManager.xmonad = {
    inherit extraPackages;
    enable = true;
    config = ./xmonad.hs;
  };
  xsession.profileExtra = ''export $(dbus-launch)'';
  xsession.enable = true;
  /*xsession.windowManager.command =*/
    /*let xmonad = pkgs.xmonad-with-packages.override {*/
      /*packages = self: [self.xmonad-contrib];*/
  /*};*/
  /*in*/
/*"${xmonad}/bin/xmonad";*/
}

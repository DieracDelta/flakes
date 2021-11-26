{ pkgs, home-manager, ... }:
{
  environment.systemPackages = with pkgs; [ vim ghc ripgrep tree zathura yabai alacritty jq zoxide starship direnv fzf exa];


  services.yabai = {
    enable = true;
    package = pkgs.yabai;
    config = {
      focus_follows_mouse = "on";
      mouse_follows_focus = "off";
      window_placement = "second_child";
      window_opacity = "off";
      top_padding = 3;
      bottom_padding = 3;
      left_padding = 3;
      right_padding = 3;
      window_gap = 3;
      layout = "bsp";
    };
  };

  services.skhd = {
    enable = true;
    skhdConfig = builtins.readFile ./shkdrc;
  };

  services.nix-daemon.enable = true;
  nix.package = pkgs.nixUnstable;
}

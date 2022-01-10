{ pkgs, home-manager, ... }:
let 
rust_build = pkgs.rust-bin.nightly."2021-10-10".default.override {
extensions = [ "rust-src" "clippy" "cargo" "rustfmt-preview"];
}; in
{
  fonts = {
    enableFontDir = true;
    fonts = with pkgs;[ (nerdfonts.override { fonts = [ "FiraCode" ]; }) hack-font ];
  };

  environment.variables = { EDITOR = "nvim"; };

  environment.systemPackages = with pkgs; [ nvim ghc ripgrep tree zathura yabai alacritty jq zoxide starship direnv fzf exa tmux bat tldr neofetch bottom htop nix coreutils fd nix-du nix-top nixfmt entr zsh syncthing];


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
  nix.package = pkgs.nix;
}

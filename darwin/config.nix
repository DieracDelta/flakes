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

  environment.systemPackages = with pkgs; [ nvim ghc ripgrep tree zathura jq zoxide starship direnv fzf exa  bat tldr neofetch bottom htop nix coreutils fd nix-du nix-top nixfmt entr zsh syncthing /* colmena */ tmux /* colima */ zellij jless git-filter-repo lima bash zathura emacs /* agda */  docker  awscli emacs
  ( rWrapper.override{ packages = with rPackages; [ ggplot2 dplyr xts languageserver ]; })
  ];


  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
}

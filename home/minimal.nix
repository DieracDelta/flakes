# Minimal home-manager config for servers (ARM OCI, etc.)
# Only includes: fish, atuin, zoxide, tmux, git
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./fish.nix
    ./zoxide.nix
    ./tmux.nix
    ./htop.nix
    ./fzf.nix
    ./atuin.nix
  ];

  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
  };

  home.stateVersion = "25.11";

  # fish.nix has a profile option - enable it
  profiles.zsh.enable = true;

  # Atuin config moved to ./atuin.nix

  # Git - basic config
  programs.git = {
    enable = true;
    settings.user = {
      name = "Justin Restivo";
      email = "justin@restivo.me";
    };
    lfs.enable = true;
  };
}

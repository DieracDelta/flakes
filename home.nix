{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.stateVersion = "19.09";
  programs.git.enable = true;

  programs.fzf.enableZshIntegration = true;
  imports = [ ./dotfiles/zsh.nix ./dotfiles/nvim.nix ./creds.nix ./dotfiles/emacs.nix];

  programs.tmux.enable = true;
  programs.tmux.historyLimit = 1000000;
  programs.tmux.extraConfig = builtins.readFile ./dotfiles/tmux.conf;


  nixpkgs.overlays = [ (import ./overs) ] ;
  home.packages = [ pkgs.rootbar pkgs.clipman pkgs.wl-clipboard pkgs.deepfry pkgs.imagemagick pkgs.wofi pkgs.zathura_rice];
  manual.html.enable = true;


}

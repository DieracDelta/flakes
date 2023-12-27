{ pkgs, home-manager, ... }:
{
  fonts = {
    enableFontDir = true;
    fonts = with pkgs;[ (nerdfonts.override { fonts = [ "FiraCode" ]; }) hack-font ];
  };

  environment.variables = { EDITOR = "nvim"; };

  users.users.jrestivo.home = "/Users/jrestivo";

  environment.systemPackages = with pkgs; [ ghc ripgrep tree zathura jq zoxide starship direnv fzf eza  bat tldr neofetch bottom htop coreutils fd
  # nix-du
  nix-top nixfmt entr zsh syncthing /* colmena */ tmux /* colima */ zellij jless git-filter-repo lima zathura emacs /* agda */  docker  awscli emacs /* neovide */ /* nyxt-3 */
  ( rWrapper.override{ packages = with rPackages; [ ggplot2 dplyr xts languageserver ]; })
  amethyst
  /* jujutsu */ #vcs
  # gitoxide
  coqPackages.coq-lsp
  coq
  hyperfine
  anki-bin
  nixVeryUnstable

  ];


  services.nix-daemon.enable = true;
  nix.package = pkgs.nixVeryUnstable;
}

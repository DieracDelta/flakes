{ pkgs, home-manager, lib, ... }:
{
  fonts = {
    enableFontDir = true;
    fonts = with pkgs;[ (nerdfonts.override { fonts = [ "FiraCode" ]; }) hack-font ];
  };

  environment.variables = { EDITOR = "nvim"; };

  users.users.jrestivo.home = "/Users/jrestivo";
  users.users.jrestivo.shell = pkgs.fish;

  environment.systemPackages = with pkgs; [ ghc ripgrep tree
  # (zathura.overrideAttrs (attrs:  attrs // /* {nativeBuildInputs = attrs.nativeBuildInputs ++ [pkgs.xvfb-run]; */ { mesonFlags = ["-Ddocs=disabled" # docs do not seem to be installed
    # (lib.mesonEnable "tests" false)]; }))
    jq zoxide starship direnv fzf eza  bat tldr neofetch bottom htop coreutils fd
  # nix-du
  nix-top nixfmt entr fish syncthing /* colmena */ zellij /* colima */ zellij jless git-filter-repo lima zathura emacs /* agda */  docker  awscli emacs /* neovide */ /* nyxt-3 */
  atuin
  ( rWrapper.override{ packages = with rPackages; [ ggplot2 dplyr xts languageserver ]; })
  # amethyst
  /* jujutsu */ #vcs
  # gitoxide
  coqPackages.coq-lsp
  coq
  hyperfine
  anki-bin
  nix
  ripgrep-all
  fishPlugins.fzf-fish

  corepack_latest
  nodejs_latest
  delta duf broot


  ];


  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  # environment.systemPath = [ "/opt/homebrew/bin" ];
  environment.variables = { HOMEBREW_NO_ANALYTICS = "1"; };
  homebrew.onActivation.autoUpdate = true;
  homebrew.onActivation.cleanup = "zap";
  homebrew.global.brewfile = true;
  homebrew = {
    enable = true;
    casks = [
      {
        name = "nikitabobko/tap/aerospace";
        args = {
          no_quarantine = true;
          };
      }
    ];
  };



}

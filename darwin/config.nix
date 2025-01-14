{ pkgs, home-manager, lib, ... }:
{
  fonts = {
    packages = with pkgs;[ nerd-fonts.fira-code hack-font ];
  };

  environment.variables = { EDITOR = "nvim"; };
  system.stateVersion = 5;

  programs.fish.enable = true;
  users.users.jrestivo.home = "/Users/jrestivo";
  users.users.jrestivo.shell = pkgs.fish;

  environment.systemPackages = with pkgs; [ ghc ripgrep tree
  tdf
  moreutils
  fix-python
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
  # coqPackages.coq-lsp
  # coq
  # ocamlPackages.menhir
  # ocamlPackages.menhirLib
  # ocaml
  hyperfine
  # cargo
  ruby
  anki-bin
  nix
  ripgrep-all
  # rustc
  fishPlugins.fzf-fish
  yazi

  corepack_latest
  nodejs_latest
  delta duf broot
  mosh
  dive
  nix-output-monitor
  john


  ];


  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.extraOptions = "experimental-features = nix-command flakes";


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

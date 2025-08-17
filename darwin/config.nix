{ pkgs, home-manager, ... }:
{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      fira-code-symbols
      fira-math
      hack-font
    ];
  };

  environment.variables = {
    EDITOR = "nvim";
  };
  system.stateVersion = 5;

  programs.fish.enable = true;
  users.users.jrestivo.home = "/Users/jrestivo";
  users.users.jrestivo.shell = pkgs.fish;

  environment.systemPackages = with pkgs; [
    ghc
    moonlight-qt
    ripgrep
    tree
    # tdf
    gitoxide
    fselect
    pngpaste
    moreutils
    jq
    zoxide
    starship
    direnv
    fzf
    eza
    bat
    tldr
    neofetch
    bottom
    htop
    coreutils
    eternal-terminal
    magic-wormhole-rs
    fd
    nix-top
    entr
    fish
    syncthing # colmena
    zellij # colima
    zellij
    jless
    git-filter-repo
    lima
    zathura
    emacs # agda
    docker
    awscli
    emacs # neovide nyxt-3
    atuin
    #(rWrapper.override{ packages = with rPackages; [ ggplot2 dplyr xts languageserver ]; })
    gh
    hyperfine
    kitty
    ruby
    anki-bin
    nix
    ripgrep-all
    yazi
    corepack_latest
    nodejs_latest
    delta
    duf
    broot
    mosh
    dive
    nix-output-monitor
    sbcl_2_4_10
    libfixposix
    pkg-config
    john
  ];

  nix.package = pkgs.nix;
  nix.extraOptions = "experimental-features = nix-command flakes pipe-operators";

  # environment.systemPath = [ "/opt/homebrew/bin" ];
  environment.variables = {
    HOMEBREW_NO_ANALYTICS = "1";
  };
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

# Host-specific atuin theming
# Darwin (green) -> Forest green theme
# ARM (red) -> Crimson red theme
# Default -> Original gruvbox
{ pkgs, lib, ... }:
let
  # Theme name based on host
  themeName =
    if pkgs.stdenv.isDarwin then "gruvbox-darwin"
    else if pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.isLinux then "gruvbox-arm"
    else "gruvbox";

  # Color palettes matching tmux themes
  themes = {
    gruvbox-darwin = {
      # Forest green theme
      Base = "#d4e5d0";
      Title = "#7ec47e";
      Important = "#7ec47e";
      Guidance = "#5f9e5f";
      Annotation = "#809a7c";
      Muted = "#6e8a6a";
      AlertInfo = "#7ea0c4";
      AlertWarn = "#c4c47e";
      AlertError = "#c47e7e";
    };
    gruvbox-arm = {
      # Crimson red theme
      Base = "#e5d4d0";
      Title = "#c47070";
      Important = "#c47070";
      Guidance = "#9e4f4f";
      Annotation = "#9a807c";
      Muted = "#8a6e6a";
      AlertInfo = "#7e90c4";
      AlertWarn = "#c4a07e";
      AlertError = "#c47070";
    };
    gruvbox = {
      # Original gruvbox
      Base = "#ebdbb2";
      Title = "#fabd2f";
      Important = "#fabd2f";
      Guidance = "#d79921";
      Annotation = "#a89984";
      Muted = "#928374";
      AlertInfo = "#83a598";
      AlertWarn = "#fe8019";
      AlertError = "#fb4934";
    };
  };
in
{
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = pkgs.stdenv.isDarwin;
    settings = {
      # Use our custom theme
      theme.name = themeName;

      # Self-hosted sync server
      sync_address = "http://100.74.54.40:4200";

      # Behavior settings
      workspaces = true;
      enter_accept = true;
      keymap_mode = "vim-insert";

      # Sync v2
      sync.records = true;

      # Disable mail
      mail.enabled = false;

      # Stats configuration
      stats = {
        common_subcommands = [
          "apt"
          "cargo"
          "composer"
          "dnf"
          "docker"
          "git"
          "go"
          "ip"
          "kubectl"
          "nix"
          "nmcli"
          "npm"
          "pecl"
          "pnpm"
          "podman"
          "port"
          "systemctl"
          "tmux"
          "yarn"
        ];
        ignored_commands = [ "ls" ];
      };
    };
  };

  # Write the theme file
  xdg.configFile."atuin/themes/${themeName}.toml".text = ''
    [theme]
    name = "${themeName}"

    [colors]
    Base = "${themes.${themeName}.Base}"
    Title = "${themes.${themeName}.Title}"
    Important = "${themes.${themeName}.Important}"
    Guidance = "${themes.${themeName}.Guidance}"
    Annotation = "${themes.${themeName}.Annotation}"
    Muted = "${themes.${themeName}.Muted}"
    AlertInfo = "${themes.${themeName}.AlertInfo}"
    AlertWarn = "${themes.${themeName}.AlertWarn}"
    AlertError = "${themes.${themeName}.AlertError}"
  '';
}

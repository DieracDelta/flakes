# Host-specific fzf theming
# Darwin (green) -> Forest green theme
# ARM (red) -> Crimson red theme
# Default -> Original gruvbox
{ pkgs, lib, ... }:
let
  # Color palettes matching tmux themes
  colors = {
    darwin = {
      # Forest green (from palette_darwin.sh)
      fg = "#d4e5d0";
      bg = "#1a2420";
      hl = "#7ec47e";
      fgPlus = "#e8f5e4";
      bgPlus = "#243330";
      hlPlus = "#7ec47e";
      info = "#5f9e5f";
      prompt = "#7ec47e";
      pointer = "#7ec47e";
      marker = "#7ec4c4";
      spinner = "#a07ec4";
      header = "#5f7e9e";
    };
    arm = {
      # Crimson red (from palette_nixos_arm.sh)
      fg = "#e5d4d0";
      bg = "#241a1a";
      hl = "#c47070";
      fgPlus = "#f5e8e4";
      bgPlus = "#332424";
      hlPlus = "#c47070";
      info = "#9e4f4f";
      prompt = "#c47070";
      pointer = "#c47070";
      marker = "#7ea0a0";
      spinner = "#a07ea0";
      header = "#5f6e9e";
    };
    default = {
      # Original gruvbox
      fg = "#ebdbb2";
      bg = "#282828";
      hl = "#fabd2f";
      fgPlus = "#ebdbb2";
      bgPlus = "#3c3836";
      hlPlus = "#fabd2f";
      info = "#83a598";
      prompt = "#fabd2f";
      pointer = "#fabd2f";
      marker = "#8ec07c";
      spinner = "#d3869b";
      header = "#83a598";
    };
  };

  palette =
    if pkgs.stdenv.isDarwin then colors.darwin
    else if pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.isLinux then colors.arm
    else colors.default;
in
{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    colors = {
      fg = palette.fg;
      bg = palette.bg;
      hl = palette.hl;
      "fg+" = palette.fgPlus;
      "bg+" = palette.bgPlus;
      "hl+" = palette.hlPlus;
      info = palette.info;
      prompt = palette.prompt;
      pointer = palette.pointer;
      marker = palette.marker;
      spinner = palette.spinner;
      header = palette.header;
    };
  };
}

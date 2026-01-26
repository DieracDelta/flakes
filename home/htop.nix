# Host-specific htop theming
# Darwin (green) -> MC color scheme (4) - has green elements
# ARM (red) -> Black Night color scheme (5) - warmer/darker tones
# Default -> Default color scheme (0)
{
  pkgs,
  lib,
  ...
}:
let
  colorScheme =
    if pkgs.stdenv.isDarwin then 4        # MC (green-ish)
    else if pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.isLinux then 5  # Black Night (warm)
    else 0;                                # Default
in
{
  programs.htop = {
    enable = true;
    settings = {
      color_scheme = colorScheme;
      highlight_base_name = 1;
      show_program_path = 0;
      tree_view = 1;
      hide_kernel_threads = 1;
      hide_userland_threads = 1;
    };
  };
}

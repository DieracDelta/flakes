{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom_modules.pijul-flakes;
  plugin = pkgs.nix-plugin-pijul;
in
{
  options.custom_modules.pijul-flakes.enable = lib.mkEnableOption "Pijul flake inputs";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = plugin.nixPackage.drvPath == config.nix.package.drvPath;
        message = "nix-plugin-pijul must be built against the configured nix.package";
      }
    ];

    environment.systemPackages = [
      pkgs.pijul
      plugin
    ];

    # Nix plugins use an unstable C++ ABI. The assertion above prevents the
    # daemon from loading a plugin built against a different Nix derivation.
    nix.settings.plugin-files = [ "${plugin}/lib/nix/plugins/pijul.so" ];
  };
}

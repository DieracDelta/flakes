# External packages from other inputs
# This overlay requires inputs to be passed in via a factory function
{
  nix,
  my-nvim,
  nixpkgs-master,
}:
let
  # Import nixpkgs-master with allowUnfree for packages like trezor-suite
  pkgs-master = import nixpkgs-master {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
final: prev: {
  nix = nix.packages.x86_64-linux.default;
  nvim = my-nvim.defaultPackage.x86_64-linux;
  # TODO fix this -- it's very broken and IDK why
  influxdb2 = pkgs-master.influxdb2;
  # Use latest trezor-suite from master (25.11.1 in stable has connection bugs)
  trezor-suite = pkgs-master.trezor-suite;
}

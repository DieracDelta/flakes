# External packages from other inputs
# This overlay requires inputs to be passed in via a factory function
{ nix, my-nvim, nixpkgs-master }:
final: prev: {
  nix = nix.packages.x86_64-linux.default;
  nvim = my-nvim.defaultPackage.x86_64-linux;
  # TODO fix this -- it's very broken and IDK why
  influxdb2 = nixpkgs-master.legacyPackages.x86_64-linux.influxdb2;
}

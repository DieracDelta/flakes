{
  coreutils,
  lib,
  nixos-rebuild,
  util-linux,
  writeShellApplication,
}:

writeShellApplication {
  name = "forgejo-nixos-test-switch";

  runtimeInputs = [
    coreutils
    nixos-rebuild
    util-linux
  ];

  text = builtins.readFile ../../scripts/forgejo-nixos-test-switch.sh;

  meta = {
    description = "Test a NixOS configuration and restore the running system";
    mainProgram = "forgejo-nixos-test-switch";
    platforms = lib.platforms.linux;
  };
}

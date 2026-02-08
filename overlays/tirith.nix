# Tirith terminal security tool
# Intercepts shell commands to detect homograph attacks, pipe-to-shell, terminal injection, etc.
{ tirith-src }:
final: prev: {
  tirith = prev.rustPlatform.buildRustPackage {
    pname = "tirith";
    version = (builtins.fromTOML (builtins.readFile "${tirith-src}/Cargo.toml")).workspace.package.version;
    src = tirith-src;
    cargoBuildFlags = [ "-p" "tirith" ];
    doCheck = false;
    cargoLock.lockFile = "${tirith-src}/Cargo.lock";
    buildInputs = prev.lib.optionals prev.stdenv.isDarwin (
      with prev.darwin.apple_sdk.frameworks; [
        Security
        SystemConfiguration
      ]
    );
  };
}

# Rust platform overlay with znver3 CPU targeting
final: prev: {
  makeRustPlatform =
    args:
    prev.callPackage "${prev.path}/pkgs/development/compilers/rust/make-rust-platform.nix" {
      GLOBAL_RUSTFLAGS = "-C target-cpu=znver3";
    } args;
}

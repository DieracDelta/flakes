final: prev: {
  rustPlatform = prev.rustPlatform.overrideScope (
    rfinal: rprev: {
      GLOBAL_RUSTFLAGS = "-C target-cpu=znver3";
    }
  );
}

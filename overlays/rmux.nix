final: _prev: {
  rmux = final.rustPlatform.buildRustPackage rec {
    pname = "rmux";
    version = "0.5.0";

    src = final.fetchCrate {
      inherit pname version;
      hash = "sha256-yNICXGviqCTzVGzjJtN/hkENsZHe3wXC1HGj/1Qkk5U=";
    };

    cargoHash = "sha256-jovAKziYEqs4EQuXxD59RKt2BkWDr+DKf0cKOAZ7YZ0=";
    buildNoDefaultFeatures = true;
    doCheck = false;

    meta = with final.lib; {
      description = "Rust terminal multiplexer";
      homepage = "https://github.com/Helvesec/rmux";
      license = with licenses; [
        mit
        asl20
      ];
      mainProgram = "rmux";
    };
  };
}

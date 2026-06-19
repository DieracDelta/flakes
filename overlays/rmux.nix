final: _prev: {
  rmux = final.rustPlatform.buildRustPackage rec {
    pname = "rmux";
    version = "0.5.0";

    src = final.fetchCrate {
      inherit pname version;
      hash = "sha256-yNICXGviqCTzVGzjJtN/hkENsZHe3wXC1HGj/1Qkk5U=";
    };
    rmuxServerSrc = final.fetchCrate {
      pname = "rmux-server";
      inherit version;
      hash = "sha256-W49oB0M+sjHHd5o6JUpQRLWnj6rVJnuFfNGctSTUyUw=";
    };
    rmuxCoreSrc = final.fetchCrate {
      pname = "rmux-core";
      inherit version;
      hash = "sha256-sz4fO0y2sZGYC/EOjQetfyhnis4TQ90S0JSfOHEjI30=";
    };

    cargoHash = "sha256-jovAKziYEqs4EQuXxD59RKt2BkWDr+DKf0cKOAZ7YZ0=";
    buildNoDefaultFeatures = true;
    doCheck = false;
    postPatch = ''
      mkdir -p vendor
      patch -p1 < ${../patches/rmux-daemon-multithread-runtime.patch}
      cp -R ${rmuxCoreSrc} vendor/rmux-core-0.5.0
      chmod -R u+w vendor/rmux-core-0.5.0
      patch -d vendor/rmux-core-0.5.0 -p1 < ${../patches/rmux-core-kitty-keyboard.patch}
      patch -d vendor/rmux-core-0.5.0 -p3 < ${../patches/rmux-core-osc52-pane-clipboard.patch}
      cp -R ${rmuxServerSrc} vendor/rmux-server-0.5.0
      chmod -R u+w vendor/rmux-server-0.5.0
      patch -d vendor/rmux-server-0.5.0 -p1 < ${../patches/rmux-server-pane-delta-preserve-cursor.patch}
      patch -d vendor/rmux-server-0.5.0 -p1 < ${../patches/rmux-server-copy-mode-osc52-clipboard.patch}
      patch -d vendor/rmux-server-0.5.0 -p3 < ${../patches/rmux-server-pane-osc52-clipboard.patch}
      patch -d vendor/rmux-server-0.5.0 -p1 < ${../patches/rmux-server-control-space-prefix.patch}
      patch -d vendor/rmux-server-0.5.0 -p1 < ${../patches/rmux-server-prefix-table-before-copy-mode.patch}
      patch -d vendor/rmux-server-0.5.0 -p1 < ${../patches/rmux-server-copy-mode-selection-style.patch}
      patch -d vendor/rmux-server-0.5.0 -p1 < ${../patches/rmux-server-attach-latency-session-lock.patch}
      substituteInPlace vendor/rmux-server-0.5.0/Cargo.toml \
        --replace-fail \
          $'[dependencies.rmux-core]\nversion = "0.5.0"' \
          $'[dependencies.rmux-core]\nversion = "0.5.0"\npath = "../rmux-core-0.5.0"'
      substituteInPlace Cargo.toml \
        --replace-fail \
          $'[dependencies.rmux-core]\nversion = "0.5.0"' \
          $'[dependencies.rmux-core]\nversion = "0.5.0"\npath = "vendor/rmux-core-0.5.0"' \
        --replace-fail \
          $'[dev-dependencies.rmux-core]\nversion = "0.5.0"' \
          $'[dev-dependencies.rmux-core]\nversion = "0.5.0"\npath = "vendor/rmux-core-0.5.0"' \
        --replace-fail \
          $'[dependencies.rmux-server]\nversion = "0.5.0"\ndefault-features = false' \
          $'[dependencies.rmux-server]\nversion = "0.5.0"\npath = "vendor/rmux-server-0.5.0"\ndefault-features = false'
    '';

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

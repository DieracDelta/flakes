final: _prev: {
  rmux = final.rustPlatform.buildRustPackage rec {
    pname = "rmux";
    version = "0.10.0";

    src = final.fetchCrate {
      inherit pname version;
      hash = "sha256-4Zghqd9ROd2fkHLxC+UbspNSkv9gNEhCBHh1hMB40Z4=";
    };
    rmuxServerSrc = final.fetchCrate {
      pname = "rmux-server";
      inherit version;
      hash = "sha256-aZ2oVRNe1m6gRT42fcALvvXTp3Rq0GD9uiTcc+b+YVo=";
    };
    rmuxCoreSrc = final.fetchCrate {
      pname = "rmux-core";
      inherit version;
      hash = "sha256-mWKtjBg0eCQQy0wrIIH5sFWU1l0+Kld26o6/R3TXxGo=";
    };
    rmuxOsSrc = final.fetchCrate {
      pname = "rmux-os";
      inherit version;
      hash = "sha256-0qQ2b3GsoaqSrNX5ml372jjmB79q2nKqMDdpeGiu0uo=";
    };

    cargoHash = "sha256-VKh4v16cU/XJxJVWFDrXGgSaOm4HCmHY58zFMrC31uA=";
    buildNoDefaultFeatures = true;
    doCheck = false;
    postPatch = ''
            mkdir -p vendor
            cp -R ${rmuxCoreSrc} vendor/rmux-core-0.10.0
            cp -R ${rmuxOsSrc} vendor/rmux-os-0.10.0
            cp -R ${rmuxServerSrc} vendor/rmux-server-0.10.0
            chmod -R u+w vendor

            # Most of the 0.5.0 patch stack landed upstream by 0.10.0. Keep only
            # the local child-priority reset and opt-in pane lifecycle diagnostics.
            patch -d vendor/rmux-os-0.10.0 -p1 < ${../patches/rmux-os-reset-pane-child-priority.patch}
            patch -d vendor/rmux-server-0.10.0 -p1 < ${../patches/rmux-server-pane-lifecycle-log.patch}

            substituteInPlace vendor/rmux-server-0.10.0/Cargo.toml \
              --replace-fail \
                $'[dependencies.rmux-core]\nversion = "0.10.0"' \
                $'[dependencies.rmux-core]\nversion = "0.10.0"\npath = "../rmux-core-0.10.0"' \
              --replace-fail \
                $'[dependencies.rmux-os]\nversion = "0.10.0"' \
                $'[dependencies.rmux-os]\nversion = "0.10.0"\npath = "../rmux-os-0.10.0"' \
              --replace-fail \
                $'[dev-dependencies.rmux-core]\nversion = "0.10.0"' \
                $'[dev-dependencies.rmux-core]\nversion = "0.10.0"\npath = "../rmux-core-0.10.0"'
            substituteInPlace Cargo.toml \
              --replace-fail \
                $'[dependencies.rmux-core]\nversion = "0.10.0"' \
                $'[dependencies.rmux-core]\nversion = "0.10.0"\npath = "vendor/rmux-core-0.10.0"' \
              --replace-fail \
                $'[dependencies.rmux-os]\nversion = "0.10.0"' \
                $'[dependencies.rmux-os]\nversion = "0.10.0"\npath = "vendor/rmux-os-0.10.0"' \
              --replace-fail \
                $'[dev-dependencies.rmux-core]\nversion = "0.10.0"' \
                $'[dev-dependencies.rmux-core]\nversion = "0.10.0"\npath = "vendor/rmux-core-0.10.0"' \
              --replace-fail \
                $'[dependencies.rmux-server]\nversion = "0.10.0"\ndefault-features = false' \
                $'[dependencies.rmux-server]\nversion = "0.10.0"\npath = "vendor/rmux-server-0.10.0"\ndefault-features = false'
            cat >> Cargo.toml <<'EOF'

      [patch.crates-io]
      rmux-core = { path = "vendor/rmux-core-0.10.0" }
      rmux-os = { path = "vendor/rmux-os-0.10.0" }
      rmux-server = { path = "vendor/rmux-server-0.10.0" }
      EOF
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

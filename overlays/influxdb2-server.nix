{
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  go-bindata,
  lib,
  perl,
  pkg-config,
  rustPlatform,
  stdenv,
  libiconv,
}:

let
  version = "2.9.1";
  uiVersion = "OSS-v2.9.0";
  libfluxVersion = "0.200.0";

  src = fetchFromGitHub {
    owner = "influxdata";
    repo = "influxdb";
    rev = "v${version}";
    hash = "sha256-Q/FiiYaLpI6fQIoAj5s3nMV7Fcm3cjMKGiht89DIonA=";
  };

  ui = fetchurl {
    url = "https://github.com/influxdata/ui/releases/download/${uiVersion}/build.tar.gz";
    hash = "sha256-nLLfgY8fW63CPgUfUe736LFDVAIzlHYG6trTCfOVuw4=";
  };

  flux = rustPlatform.buildRustPackage (finalAttrs: {
    pname = "libflux";
    version = libfluxVersion;

    src = fetchFromGitHub {
      owner = "influxdata";
      repo = "flux";
      rev = "v${libfluxVersion}";
      hash = "sha256-naQKGSYt+zI8N8ydFo0PBNUFnlkieW0Drz/VVeHlL0Q=";
    };

    # Flux 0.200.0 contains the former unsigned-char fix upstream. Keep only
    # nixpkgs' warning-policy adaptation for the C FFI build.
    postPatch = ''
      substituteInPlace flux/Cargo.toml \
        --replace-fail 'default = ["strict", ' 'default = ['
      substituteInPlace flux-core/Cargo.toml \
        --replace-fail 'default = ["strict"]' 'default = []'
    '';

    sourceRoot = "${finalAttrs.src.name}/libflux";
    cargoHash = "sha256-E5A8PMblOIvZBWKcA+LkRmlSp8JR0pZy0bYMj7hftTg=";

    nativeBuildInputs = [ rustPlatform.bindgenHook ];
    buildInputs = lib.optional stdenv.hostPlatform.isDarwin libiconv;

    postInstall = ''
            mkdir -p $out/include $out/pkgconfig
            cp -r include/influxdata $out/include
            cat > $out/pkgconfig/flux.pc <<EOF
      Name: flux
      Version: ${libfluxVersion}
      Description: Library for the InfluxData Flux engine
      Cflags: -I$out/include
      Libs: -L$out/lib -lflux -lpthread
      EOF
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      install_name_tool -id $out/lib/libflux.dylib $out/lib/libflux.dylib
    '';

    __structuredAttrs = true;
  });
in
buildGoModule {
  pname = "influxdb";
  inherit version src;

  nativeBuildInputs = [
    go-bindata
    pkg-config
    perl
  ];

  # Go 1.25 applies GOFLAGS=-mod=vendor even while buildGoModule is still
  # constructing the vendor tree, so the UI's preBuild `go generate` sees an
  # incomplete vendor/modules.txt. Populate the module proxy instead and keep
  # UI generation out of the fixed-output dependency derivation.
  vendorHash = "sha256-/W2FD3PMAAaaeyMngMGluSeDiuphV7NH6o6BMqLpLBM=";
  proxyVendor = true;
  overrideModAttrs = _: {
    preBuild = "";
  };

  subPackages = [
    "cmd/influxd"
    "cmd/telemetryd"
  ];

  env.PKG_CONFIG_PATH = "${flux}/pkgconfig";

  postPatch = ''
    substituteInPlace static/static.go \
      --replace-fail 'go run github.com/kevinburke/go-bindata/' ""
  '';

  preBuild = ''
    flux_ver=$(grep github.com/influxdata/flux go.mod | awk '{print $2}')
    if [ "$flux_ver" != "v${libfluxVersion}" ]; then
      echo "go.mod wants libflux $flux_ver, but this derivation provides ${libfluxVersion}" >&2
      exit 1
    fi

    ui_ver=$(grep -E 'UI_RELEASE=".*"' scripts/fetch-ui-assets.sh | cut -d'"' -f2)
    if [ "$ui_ver" != "${uiVersion}" ]; then
      echo "scripts/fetch-ui-assets.sh wants UI $ui_ver, but this derivation provides ${uiVersion}" >&2
      exit 1
    fi

    mkdir -p static/data
    tar -xzf ${ui} -C static/data
    pushd static
    go generate
    popd
  '';

  tags = [ "assets" ];

  ldflags = [
    "-X main.commit=v${version}"
    "-X main.version=${version}"
  ];

  passthru = {
    inherit flux;
  };

  meta = {
    description = "Open-source distributed time series database";
    license = lib.licenses.mit;
    homepage = "https://influxdata.com/";
    maintainers = [ ];
  };
}

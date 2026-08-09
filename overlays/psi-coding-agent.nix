{
  src,
  gitCommit,
}:
final: _prev: {
  # Build against the configured package set instead of importing the input's
  # independent nixpkgs. This keeps Psi in the Zen 3 system closure and avoids
  # a second generic glibc/toolchain graph.
  psi-coding-agent = final.callPackage (
    {
      lib,
      stdenv,
      buildPackages,
      gnumake,
      pkg-config,
      makeWrapper,
      argtable,
      cjson,
      curl,
      libedit,
      lua5_5,
      zlib,
      cacert,
      forgejo-mcp,
    }:
    let
      isCross = stdenv.buildPlatform != stdenv.hostPlatform;
    in
    stdenv.mkDerivation {
      pname = "psi";
      version = "0.1.0";
      inherit src;

      nativeBuildInputs = [
        gnumake
        pkg-config
        makeWrapper
      ]
      ++ lib.optional isCross buildPackages.zlib;
      buildInputs = [
        argtable
        cjson
        curl
        libedit
        lua5_5
        zlib
      ];

      makeFlags = [
        "CC=${stdenv.cc.targetPrefix}cc"
        "HOST_CC=${buildPackages.stdenv.cc}/bin/cc"
        "PKG_CONFIG=pkg-config"
        "CA_BUNDLE_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
        "LUA_BOOT_FILE=$(out)/share/psi/boot.lua"
        "GIT_COMMIT=${gitCommit}"
      ];

      preBuild = lib.optionalString isCross ''
        makeFlagsArray+=(
          "HOST_CFLAGS_ZLIB=-I${buildPackages.zlib.dev}/include"
          "HOST_LIBS_ZLIB=-L${buildPackages.zlib.out}/lib -lz"
        )
      '';

      installFlags = [ "PREFIX=$(out)" ];

      installPhase = ''
        runHook preInstall
        make $makeFlags "''${makeFlagsArray[@]}" PREFIX="$out" install
        runHook postInstall
      '';

      postFixup = ''
        wrapProgram "$out/bin/psi" \
          --suffix PATH : ${lib.makeBinPath [ forgejo-mcp ]}
      '';

      meta = {
        description = "Terminal-native coding agent built around Lua 5.5";
        homepage = "https://office-desktop.tail5ca7.ts.net/forgejo/jrestivo/psi-coding-agent";
        license = lib.licenses.mit;
        mainProgram = "psi";
        platforms = lib.platforms.linux;
      };
    }
  ) { };
}

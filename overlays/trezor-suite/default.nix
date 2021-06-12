# stolen from https://hg.lukegb.com/lukegb/depot/-/blob/branch/default/third_party/nixpkgs/pkgs/applications/blockchains/trezor-suite/default.nix#L18
{ lib
, stdenv
, fetchurl
, appimageTools
, tor
, trezord
, libxshmfence
}:

let
  pname = "trezor-suite";
  version = "21.5.1";
  name = "${pname}-${version}";

  suffix = {
    aarch64-linux = "linux-arm64";
    x86_64-linux  = "linux-x86_64";
  }.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/trezor/${pname}/releases/download/v${version}/Trezor-Suite-${version}-${suffix}.AppImage";
    # sha512 hashes are obtained from latest-linux-arm64.yml and latest-linux.yml
    sha512 = {
      aarch64-linux = "sha512-nqwfonWySc+wBSJjC8BW9vm+v5zHbKqbbrTTRmoZdEYBJg2SthMtTULNLVpXaX9NHxr6guZnOWdBlzVk2dQkfQ==";
      x86_64-linux  = "sha512-tfvdNXsjMe8YXJwTuujz4tKTdfsCuR/9VECF8EkcRP95YM7vuDV8dumru1jKtdiv0gaS1GT3SPEeAfmczY5jGg==";
    }.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  };

  appimageContents = appimageTools.extractType2 {
    inherit name src;
  };

in

appimageTools.wrapType2 rec {
  inherit name src;

  extraPkgs = pkgs: [pkgs.xorg.libxshmfence];

  extraInstallCommands = ''
    mv $out/bin/${name} $out/bin/${pname}
    mkdir -p $out/bin $out/share/${pname} $out/share/${pname}/resources

    cp -a ${appimageContents}/locales/ $out/share/${pname}
    cp -a ${appimageContents}/resources/app*.* $out/share/${pname}/resources
    cp -a ${appimageContents}/resources/images/ $out/share/${pname}/resources

    install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop
    install -m 444 -D ${appimageContents}/${pname}.png $out/share/icons/hicolor/512x512/apps/${pname}.png
    install -m 444 -D ${appimageContents}/resources/images/icons/512x512.png $out/share/icons/hicolor/512x512/apps/${pname}.png
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace 'Exec=AppRun' 'Exec=${pname}'

    # symlink system binaries instead bundled ones
    mkdir -p $out/share/${pname}/resources/bin/{bridge,tor}
    ln -sf ${trezord}/bin/trezord-go $out/share/${pname}/resources/bin/bridge/trezord
    ln -sf ${tor}/bin/tor $out/share/${pname}/resources/bin/tor/tor
  '';

  #LD_LIBRARY_PATH="{libxshmfence}/lib/";

  meta = with lib; {
    description = "Trezor Suite - Desktop App for managing crypto";
    homepage = "https://suite.trezor.io";
    license = licenses.unfree;
    maintainers = with maintainers; [ prusnak ];
    platforms = [ "aarch64-linux" "x86_64-linux" ];
  };
}
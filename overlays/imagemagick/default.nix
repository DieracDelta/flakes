{ stdenv
, fetchFromGitHub
, fetchpatch
, pkg-config
, libtool
, bzip2
, zlib
, libX11
, libXext
, libXt
, fontconfig
, freetype
, ghostscript
, libjpeg
, djvulibre
, lcms2
, openexr
, libpng
, liblqr1
, librsvg
, libtiff
, libxml2
, openjpeg
, libwebp
, fftw
, libheif
, libde265
}:
let
  arch =
    if stdenv.hostPlatform.system == "i686-linux" then
      "i686"
    else if stdenv.hostPlatform.system == "x86_64-linux"
      || stdenv.hostPlatform.system == "x86_64-darwin" then
      "x86-64"
    else if stdenv.hostPlatform.system == "armv7l-linux" then
      "armv7l"
    else if stdenv.hostPlatform.system == "aarch64-linux" then
      "aarch64"
    else
      throw "ImageMagick is not supported on this platform.";

  cfg = {
    version = "6.9.10-71";
    sha256 = "0c69xmr8k8c4dplgzxydm30s2dr8biq71x07hc15bw196nsx3srr";
    patches = [ ];
  }
  # Freeze version on mingw so we don't need to port the patch too often.
  # FIXME: This version has multiple security vulnerabilities
  // stdenv.lib.optionalAttrs (stdenv.hostPlatform.isMinGW) {
    version = "6.9.2-0";
    sha256 = "17ir8bw1j7g7srqmsz3rx780sgnc21zfn0kwyj78iazrywldx8h7";
    patches = [
      (fetchpatch {
        name = "mingw-build.patch";
        url = "https://raw.githubusercontent.com/Alexpux/MINGW-packages/"
          + "01ca03b2a4ef/mingw-w64-imagemagick/002-build-fixes.patch";
        sha256 = "1pypszlcx2sf7wfi4p37w1y58ck2r8cd5b2wrrwr9rh87p7fy1c0";
      })
    ];
  };

in
stdenv.mkDerivation {
  pname = "imagemagick";
  inherit (cfg) version;

  src = fetchFromGitHub {
    owner = "ImageMagick";
    repo = "ImageMagick6";
    rev = cfg.version;
    inherit (cfg) sha256;
  };

  patches = cfg.patches;

  outputs = [ "out" "dev" "doc" ]; # bin/ isn't really big
  outputMan = "out"; # it's tiny

  enableParallelBuilding = true;

  configureFlags = [ "--with-frozenpaths" ] ++ [ "--with-gcc-arch=${arch}" ]
    ++ stdenv.lib.optional (librsvg != null) "--with-rsvg"
    ++ stdenv.lib.optional (liblqr1 != null) "--with-lqr=yes"
    ++ stdenv.lib.optionals (ghostscript != null) [
    "--with-gs-font-dir=${ghostscript}/share/ghostscript/fonts"
    "--with-gslib"
  ] ++ stdenv.lib.optionals (stdenv.hostPlatform.isMinGW) [
    "--enable-static"
    "--disable-shared"
  ] # due to libxml2 being without DLLs ATM
  ;

  nativeBuildInputs = [ pkg-config libtool ];

  buildInputs = [
    zlib
    fontconfig
    freetype
    ghostscript
    liblqr1
    libpng
    libtiff
    libxml2
    libheif
    libde265
    djvulibre
  ] ++ stdenv.lib.optionals (!stdenv.hostPlatform.isMinGW) [
    openexr
    librsvg
    openjpeg
  ];

  propagatedBuildInputs = [ bzip2 freetype libjpeg lcms2 fftw ]
    ++ stdenv.lib.optionals (!stdenv.hostPlatform.isMinGW) [
    libX11
    libXext
    libXt
    libwebp
  ];

  doCheck = false; # fails 6 out of 76 tests

  postInstall = ''
    (cd "$dev/include" && ln -s ImageMagick* ImageMagick)
    moveToOutput "bin/*-config" "$dev"
    moveToOutput "lib/ImageMagick-*/config-Q16" "$dev" # includes configure params
    for file in "$dev"/bin/*-config; do
      substituteInPlace "$file" --replace "${pkg-config}/bin/pkg-config -config" \
        ${pkg-config}/bin/pkg-config
      substituteInPlace "$file" --replace ${pkg-config}/bin/pkg-config \
        "PKG_CONFIG_PATH='$dev/lib/pkg-config' '${pkg-config}/bin/pkg-config'"
    done
  '' + stdenv.lib.optionalString (ghostscript != null) ''
    for la in $out/lib/*.la; do
      sed 's|-lgs|-L${stdenv.lib.getLib ghostscript}/lib -lgs|' -i $la
    done
  '';

  meta = with stdenv.lib; {
    homepage = "http://www.imagemagick.org/";
    description =
      "A software suite to create, edit, compose, or convert bitmap images";
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = with maintainers; [ the-kenny ];
    license = licenses.asl20;
  };
}

{ stdenv
, fetchFromGitHub
, lispPackages
, sbcl
, callPackage
, webkitgtk
, pkgconfig
, openssl
, glib-networking
, glib
, pango
, cairo
, gtkd
, gdk-pixbuf
, gtk3
, libfixposix
, sqlite
, gsettings-desktop-schemas
, gstreamer
, enchant
, gst-plugins-base
}:

stdenv.mkDerivation rec {
  pname = "next";
  version = "2.0";

  # src = fetchFromGitHub {
  #   owner = "atlas-engineer";
  #   repo = "next";
  #   rev = "df6059fb1900ecaf8cd4bd4643101362b6821995";
  #   sha256 = "1jf19b6xc3zv0vz8n97vbhzlj2vx6hwfzvpp123qak6xjqf7nrw6";
  # };
  src = /home/jrestivo/fun/next;

  nativeBuildInputs = [
    webkitgtk
    sbcl
    glib-networking.out
  ] ++ (with lispPackages; [
    prove-asdf
    trivial-features
  ]);
  propagatedBuildInputs = [ openssl.out ];

  buildInputs = with lispPackages; [
    sqlite.out
    enchant.out
    gstreamer.out
    gst-plugins-base.out
    gsettings-desktop-schemas.out
    glib-networking.out
    pango.out
    cairo.out
    gtkd.out
    gdk-pixbuf.out
    gtk3.out
    glib.out
    libfixposix.out
    openssl.out
    webkitgtk
    alexandria
    bordeaux-threads
    asdf-package-system
    cl-annot
    cl-ansi-text
    cl-css
    cl-json
    cl-markup
    cl-ppcre
    cl-ppcre-unicode
    cl-prevalence
    closer-mop
    dbus
    dexador
    ironclad
    local-time
    log4cl
    lparallel
    mk-string-metrics
    parenscript
    plump
    quri
    serapeum
    sqlite
    str
    swank
    trivia
    trivial-clipboard
    trivial-types
    unix-opts
  ];

  # the solution here is to write a wrapper script that exports LD_LIBRARY_PATH as you would expect
  LD_LIBRARY_PATH = "${sqlite.out}/lib/:${gsettings-desktop-schemas.out}/lib/:${gst-plugins-base.out}/lib/:${enchant.out}/lib/:${gstreamer.out}/lib/:${glib-networking.out}/lib/gio/modules/:${webkitgtk}/lib/:${gtk3}/lib/:${pango.out}/lib/:${cairo.out}/lib/:${gdk-pixbuf.out}/lib/:${gtkd.out}/lib/:${glib.out}/lib/:${openssl.out}/lib/:${libfixposix.out}/lib";

  # environment.sessionVariables.LD_LIBRARY_PATH = [""] ;
  #   [ "${sqlite.out}/lib/:${gsettings-desktop-schemas.out}/lib/:${gst-plugins-base.out}/lib/:${enchant.out}/lib/:${gstreamer.out}/lib/:${glib-networking.out}/lib/gio/modules/:${webkitgtk}/lib/:${gtk3}/lib/:${pango.out}/lib/:${cairo.out}/lib/:${gdk-pixbuf.out}/lib/:${gtkd.out}/lib/:${glib.out}/lib/:${openssl.out}/lib/:${libfixposix.out}/lib:$LD_LIBRARY_PATH" ];

  makeFlags = [ "all" ];

  installPhase = ''
    install -D -m0755 next $out/bin/next
  '';

  # Stripping destroys the generated SBCL image
  dontStrip = true;

  meta = with stdenv.lib; {
    description = "Infinitely extensible web-browser (with Lisp development files using WebKitGTK platform port)";
    homepage = "https://next.atlas.engineer";
    license = licenses.bsd3;
    maintainers = [ maintainers.lewo ];
    platforms = [ "x86_64-linux" ];
  };
}

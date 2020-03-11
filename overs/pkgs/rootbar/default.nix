{ stdenv, fetchhg, pkg-config, wayland, gtk3, json_c, libpulseaudio }:

stdenv.mkDerivation rec {
  pname = "rootbar";
  version = "f8b43cc69e49";

  src = fetchhg {
    url = "https://hg.sr.ht/~scoopta/rootbar";
    rev = version;
    sha256 = "0l7z214z8gl5m414cw37af6ls5ba752sm1p9ylv69l37qznvzsbw";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ wayland gtk3 json_c libpulseaudio ];

  preConfigure = "cd Release";

  installPhase = "install -D rootbar $out/bin/rootbar";
}

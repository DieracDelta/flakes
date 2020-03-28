{ lib, stdenv, fetchFromGitHub, wayland, wayland-protocols, bash, grim, slurp, python37, makeWrapper, imagemagick}:
let metadata = import ./metadata.nix;
in
  stdenv.mkDerivation rec {
    name = "deepfrier";
    version = metadata.rev;

    src = fetchFromGitHub {
      owner = "DieracDelta";
      repo = "deepfry";
      rev = metadata.rev;
      sha256 = metadata.sha256;
    };


  propagatedBuildInputs = [ grim slurp  ];
  #propagatedUserEnvPackages = [ grim slurp python37Packages.tesserocr python37Packages.pillow ] ;
  #propagatedUserEnvPackages = [ grim slurp python37Packages.tesserocr python37Packages.pillow ] ;


  meta = with stdenv.lib; {
    description = "A wayland deepfrier";
    homepage = "https://github.com/DieracDelta/deepfry";
    license = licenses.mit;
    platforms = platforms.linux;
  };

  nativeBuildInputs = [ makeWrapper ];


  installPhase = ''
    mkdir -p $out/bin/
    mkdir -p $out/lib/
    cp frier.py $out/bin/
    cp bsmol.png $out/lib/
    chmod +x $out/bin/frier.py
  '';


  postFixup = ''
    makeWrapper $out/bin/frier.py $out/bin/deepfry --set-default B_LOCATION $out/lib/bsmol.png --prefix PATH : ${lib.makeBinPath [ (python37.withPackages(ps: with ps; [ pillow tesserocr ] )) ] }
  '';
}

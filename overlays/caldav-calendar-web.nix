{ src }:
final: _prev: {
  caldav-calendar-web = final.stdenvNoCC.mkDerivation {
    pname = "caldav-calendar-web";
    version = "0.1.0";
    inherit src;

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r index.html css js "$out/"
      runHook postInstall
    '';

    meta = {
      description = "CalDAV Calendar Web Frontend with Gruvbox theme";
      homepage = "https://github.com/DieracDelta/webdav-cal-simple";
      license = final.lib.licenses.mit;
      platforms = final.lib.platforms.all;
    };
  };
}

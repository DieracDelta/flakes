# Individual package overrides and custom packages
final: prev: {
  prometheus-node-exporter = prev.prometheus-node-exporter.overrideAttrs (oldAttrs: {
    src = prev.fetchFromGitHub {
      owner = "prometheus";
      repo = "node_exporter";
      tag = "v${oldAttrs.version}";
      hash = "sha256-UaybbRmcvifXNwTNXg7mIYN9JnonSxwG62KfvU5auIE=";
    };
  });

  pam-insults = final.stdenv.mkDerivation {
    pname = "pam-insults";
    version = "unstable-2025-12-19";

    src = final.fetchFromGitHub {
      owner = "cgoesche";
      repo = "pam-insults";
      rev = "2d13ef89640eb57b5e6a64eea080e57d9d936738";
      hash = "sha256-VbEJCO7lvTDKvGpTXQrpgeWEpZE4CMdwaRSuv5shsbw=";
    };

    nativeBuildInputs = [
      final.asciidoctor
      final.gzip
    ];

    buildInputs = [
      final.pam
      final.gettext
    ];

    postPatch = ''
      substituteInPlace Makefile \
        --replace-fail "sudo " "" \
        --replace-fail "mandb" ""
    '';

    makeFlags = [
      "PAM_MODULES_DIR=$(out)/lib/security"
      "MAN_DATABASE=$(out)/share/man/man8"
    ];

    preInstall = ''
      mkdir -p $out/lib/security $out/share/man/man8
    '';

    meta = with final.lib; {
      description = "PAM module that will print an insult to stderr";
      homepage = "https://github.com/cgoesche/pam-insults";
      license = licenses.gpl3Plus;
      platforms = platforms.linux;
    };
  };

  nototools = prev.nototools.overridePythonAttrs (old: {
    dontCheckRuntimeDeps = true;
    catchConflicts = false;
  });

  libp11 = prev.libp11.overrideAttrs (oldAttrs: {
    src = prev.fetchFromGitHub {
      owner = "OpenSC";
      repo = "libp11";
      rev = "${prev.libp11.pname}-${prev.libp11.version}";
      sha256 = "sha256-xH5Ic8HpWB5O2MWXf2A9FUiV10VZajDdPqEVF0Hs6u0=";
    };
  });

  libkate = prev.libkate.overrideAttrs (old: {
    src = final.fetchFromGitLab {
      domain = "gitlab.xiph.org";
      owner = "xiph";
      repo = "kate";
      rev = "kate-0.4.3";
      hash = "sha256-HwDahmjDC+O321Ba7MnHoQdHOFUMpFzaNdLHQeEg11Q=";
    };
  });

  opencv = prev.opencv.overrideAttrs (old: {
    postUnpack =
      builtins.replaceStrings
        [ "$NIX_BUILD_TOP/source/opencv_contrib" ]
        [ "$NIX_BUILD_TOP/${old.src.name}/opencv_contrib" ]
        old.postUnpack;
    preConfigure =
      builtins.replaceStrings
        [ "$NIX_BUILD_TOP/source/opencv_contrib" ]
        [ "$NIX_BUILD_TOP/${old.src.name}/opencv_contrib" ]
        old.preConfigure;
  });

  usbmuxd2 = prev.usbmuxd2.overrideAttrs (oldAttrs: {
    src = prev.fetchFromGitHub {
      owner = "tihmstar";
      repo = "usbmuxd2";
      rev = "2ce399ddbacb110bd5a83a6b8232d42c9a9b6e84";
      hash = "sha256-u7qRKH5y+Q1HnnumjVm3Ce4SlT3YaEVSPUXYOAiFBes=";
      leaveDotGit = true;
    };
  });

  # Fix dcgm-exporter to find ldconfig in PATH instead of hardcoded /sbin/ldconfig
  prometheus-dcgm-exporter = prev.prometheus-dcgm-exporter.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../patches/dcgm-exporter-fix-ldconfig.patch ];
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p $out/etc
      cp $src/etc/*.csv $out/etc/
    '';
  });
}

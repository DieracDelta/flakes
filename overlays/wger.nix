# wger Workout Manager overlay - builds from pinned upstream sources
{ wger-src, wger-react-src }:
final: _:
let
  python = final.python312;
  pythonPackages = python.pkgs;

  # Rebase the existing local nutrition and subpath behavior onto the clean,
  # pinned releases instead of depending on dirty development checkouts.
  wgerPatchedSrc = final.applyPatches {
    name = "wger-2.6-patched-source";
    src = wger-src;
    patches = [ ../patches/wger-local-nutrition-subpath.patch ];
  };
  wgerReactPatchedSrc = final.applyPatches {
    name = "wger-react-components-26.7.24-patched-source";
    src = wger-react-src;
    patches = [ ../patches/wger-react-local-nutrition-subpath.patch ];
  };
in
{
  # Python packages that need to be added or overridden for wger
  wger-python-packages = pythonPackages.overrideScope (
    pyFinal: pyPrev: {
      # wger 2.6 targets Django 6.0.
      django = pyFinal.django_6;

      # django-bootstrap-breadcrumbs2 - not in nixpkgs
      django-bootstrap-breadcrumbs2 = pyFinal.buildPythonPackage rec {
        pname = "django-bootstrap-breadcrumbs2";
        version = "1.0.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/61/9c/77ca6760f722cb577ae263131274b8a3126c92293d13a144fb8385811f07/django_bootstrap_breadcrumbs2-1.0.0-py3-none-any.whl";
          hash = "sha256-qLm1nY10hyEcZCuv/vagcQOd5VxvgtBQ+eM1PJjaYPw=";
        };

        propagatedBuildInputs = [ pyFinal.django ];
        pythonImportsCheck = [ "django_bootstrap_breadcrumbs" ];
        doCheck = false;
      };

      crispy-bootstrap5 = pyPrev.crispy-bootstrap5;

      # webencodings - needed by tinycss2
      webencodings = pyFinal.buildPythonPackage rec {
        pname = "webencodings";
        version = "0.5.1";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/f4/24/2a3e3df732393fed8b3ebf2ec078f05546de641fe1b667ee316ec1dcf3b7/webencodings-0.5.1-py2.py3-none-any.whl";
          hash = "sha256-oK8SE/PCImSXqX4rOqAafkvuT0A/lb4W/JrNKUdRSng=";
        };

        pythonImportsCheck = [ "webencodings" ];
        doCheck = false;
      };

      # tinycss2 - needed by bleach[css]
      tinycss2 = pyFinal.buildPythonPackage rec {
        pname = "tinycss2";
        version = "1.5.1";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/60/45/c7b5c3168458db837e8ceab06dc77824e18202679d0463f0e8f002143a97/tinycss2-1.5.1-py3-none-any.whl";
          hash = "sha256-NBW6D1g5wGJpaZaZgXbEo3UdGLftqu62WMnOIewVBmE=";
        };

        propagatedBuildInputs = [ pyFinal.webencodings ];
        pythonImportsCheck = [ "tinycss2" ];
        doCheck = false;
      };

      # validators - needed by django-email-verification
      validators = pyFinal.buildPythonPackage rec {
        pname = "validators";
        version = "0.35.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/fa/6e/3e955517e22cbdd565f2f8b2e73d52528b14b8bcfdb04f62466b071de847/validators-0.35.0-py3-none-any.whl";
          hash = "sha256-6MlHCX6ueJLLPSaGjWN/efR7SgVUvGuABl3+Wqw3Bd0=";
        };

        pythonImportsCheck = [ "validators" ];
        doCheck = false;
      };

      # deprecation - needed by django-email-verification
      deprecation = pyFinal.buildPythonPackage rec {
        pname = "deprecation";
        version = "2.1.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/02/c3/253a89ee03fc9b9682f1541728eb66db7db22148cd94f89ab22528cd1e1b/deprecation-2.1.0-py2.py3-none-any.whl";
          hash = "sha256-oQgRWRIQ4fsOdoqMJVF8q+q8um8L+WVk+P9FGJ+QsUo=";
        };

        propagatedBuildInputs = [ pyFinal.packaging ];
        pythonImportsCheck = [ "deprecation" ];
        doCheck = false;
      };

      invoke = pyFinal.buildPythonPackage rec {
        pname = "invoke";
        version = "3.0.3";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/5a/de/bbc12563bbf979618d17625a4e753ff7a078523e28d870d3626daa97261a/invoke-3.0.3-py3-none-any.whl";
          hash = "sha256-8RMnFl5cu4myrR2I0ykrURMzLEO4VTtJTaQ11uxvUFM=";
        };

        pythonImportsCheck = [ "invoke" ];
        doCheck = false;
      };

      django-environ = pyFinal.buildPythonPackage rec {
        pname = "django-environ";
        version = "0.13.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/c4/00/3767393ece946084e1c6830a33ffb8e39d68642e27ad5ac7d4c8bd5de866/django_environ-0.13.0-py3-none-any.whl";
          hash = "sha256-N3mdFM14Iixv2CmOSL/heWX/jlhgka1mpGPlLg57eZ4=";
        };

        pythonImportsCheck = [ "environ" ];
        doCheck = false;
      };

      # django-email-verification - not in nixpkgs
      django-email-verification = pyFinal.buildPythonPackage rec {
        pname = "django-email-verification";
        version = "0.3.3";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/9c/5a/56ac119901d82c64c9a22e28cdca14aedb4a1fb90e54467e2372b3f2a2f3/django_email_verification-0.3.3-py3-none-any.whl";
          hash = "sha256-uk2CEeVdVudSQ8qUU+ViPQ61neRynLOaZ31XpC1u8Ko=";
        };

        propagatedBuildInputs = [
          pyFinal.django
          pyFinal.deprecation
          pyPrev.pyjwt # Use nixpkgs version to avoid duplicate
          pyFinal.validators
        ];
        pythonImportsCheck = [ "django_email_verification" ];
        doCheck = false;
      };

      # lingua-language-detector - not in nixpkgs (Rust binary, needs platform-specific wheel)
      lingua-language-detector = pyFinal.buildPythonPackage rec {
        pname = "lingua-language-detector";
        version = "2.2.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/44/a0/7322a0c50db8f82836ef40b14986dfcfad17bd837bfa5782562fec143bf0/lingua_language_detector-2.2.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
          hash = "sha256-Y9mcdXC6CVJfFwLk5LI2L48ffgoPupOjpT0/Mi4AZZ0=";
        };

        pythonImportsCheck = [ "lingua" ];
        doCheck = false;
      };

      # openfoodfacts - not in nixpkgs
      openfoodfacts = pyFinal.buildPythonPackage rec {
        pname = "openfoodfacts";
        version = "5.2.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/88/1e/c0b161915ca182aef853aec5e6b764d458f0cc5c3bfa4e455f5c64f23a9c/openfoodfacts-5.2.0-py3-none-any.whl";
          hash = "sha256-Bs02atqjN7SF7928yoM9Vsuyya+t1s8zoAuznLsWB+0=";
        };

        propagatedBuildInputs = with pyFinal; [
          requests
          pydantic
          tqdm
        ];

        pythonImportsCheck = [ "openfoodfacts" ];
        doCheck = false;
      };

      # fontawesomefree - just CSS/fonts, but needed for Django static files
      fontawesomefree = pyFinal.buildPythonPackage rec {
        pname = "fontawesomefree";
        version = "6.6.0";
        format = "wheel";

        src = pyFinal.fetchPypi {
          inherit pname version;
          format = "wheel";
          python = "py3";
          dist = "py3";
          platform = "any";
          hash = "sha256-WZtXRDHJvZLtX8BU0QRaB8QjNdo2wXiE8rk0dV7vkIk=";
        };

        doCheck = false;
      };

      # django-activity-stream - not in nixpkgs
      django-activity-stream = pyFinal.buildPythonPackage rec {
        pname = "django-activity-stream";
        version = "2.0.0";
        format = "setuptools";

        # The PyPI sdist omits the Django test project and fixtures.
        src = final.fetchFromGitHub {
          owner = "justquick";
          repo = "django-activity-stream";
          tag = version;
          hash = "sha256-fZrZDCWBFx1R9GGcTkjos7blSBNx1JTdTIVLKz+E2+c=";
        };

        dependencies = [ pyFinal.django ];
        nativeCheckInputs = [
          pyFinal.pytestCheckHook
          pyFinal.pytest-django
        ];
        pytestFlags = [
          "actstream"
          "runtests/testapp"
          "runtests/testapp_nested"
        ];
        # This file covers the package's optional `drf` extra, whose
        # rest-framework-generic-relations dependency is not packaged here.
        disabledTestPaths = [ "runtests/testapp/tests/test_drf.py" ];
        pythonImportsCheck = [ "actstream" ];
      };

      # django-sortedm2m - not in nixpkgs
      django-sortedm2m = pyFinal.buildPythonPackage rec {
        pname = "django-sortedm2m";
        version = "4.0.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/4f/59/368d68a415b2818dcf95044a14caa435d0140960be3b23ea8b264c8afda7/django_sortedm2m-4.0.0-py2.py3-none-any.whl";
          hash = "sha256-fnbz8+oxhLTKHUBD7HUxbGBtAPVTT8ceaZgdiyGY/zM=";
        };

        propagatedBuildInputs = [ pyFinal.django ];
        pythonImportsCheck = [ "sortedm2m" ];
        doCheck = false;
      };

      # drf-spectacular-sidecar - static files for API docs
      drf-spectacular-sidecar = pyFinal.buildPythonPackage rec {
        pname = "drf-spectacular-sidecar";
        version = "2026.1.1";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/db/96/38725edda526f3e9e597f531beeec94b0ef433d9494f06a13b7636eecb6e/drf_spectacular_sidecar-2026.1.1-py3-none-any.whl";
          hash = "sha256-r432LxtZTsKANRM22Dfq8kAqslprwqH6167pk1ghBw8=";
        };

        propagatedBuildInputs = [ pyFinal.django ];
        pythonImportsCheck = [ "drf_spectacular_sidecar" ];
        doCheck = false;
      };

      # django-recaptcha - not in nixpkgs (optional, disabled in settings)
      django-recaptcha = pyFinal.buildPythonPackage rec {
        pname = "django-recaptcha";
        version = "4.1.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/8b/e7/0765f98e4953e26573512284995648c439b0eb252877b655683d28c90be2/django_recaptcha-4.1.0-py3-none-any.whl";
          hash = "sha256-RjqmWWfpc95GayjOjotquy+v+xzgx/qhvw5bBB4El8s=";
        };

        propagatedBuildInputs = [ pyFinal.django ];
        pythonImportsCheck = [ "django_recaptcha" ];
        doCheck = false;
      };
    }
  );

  # Build the matching wger React components from the pinned release source.
  wger-react-components = final.buildNpmPackage {
    pname = "wger-react-components";
    version = "26.7.24";
    src = wgerReactPatchedSrc;
    npmDepsHash = "sha256-oz62792Dkc3jXIm9pOtz3u/oBV4DLHjL2FmomM8/ns4=";

    buildPhase = ''
      npm run build
      npm run typecheck
    '';

    installPhase = ''
      mkdir -p $out
      cp -r build $out/
      cp package.json $out/
    '';
  };

  # Node modules for wger static assets (bootstrap, popper, jquery, etc.)
  # Also compiles SCSS to CSS
  wger-node-modules = final.buildNpmPackage {
    pname = "wger-node-modules";
    version = "2.6";
    src = wgerPatchedSrc;
    npmDepsHash = "sha256-Ygu3GmN18UoEu8YQGkSNjeWu0jv3gSurjatkrEiECSo=";
    nativeBuildInputs = [ final.dart-sass ];
    npmFlags = [ "--include=dev" ];

    buildPhase = ''
      # Compile SCSS to CSS
      sass wger/core/static/scss/main.scss wger/core/static/bootstrap-compiled.css
    '';

    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
      # Replace npm react-components with locally built version
      rm -rf $out/node_modules/@wger-project/react-components
      mkdir -p $out/node_modules/@wger-project/react-components
      cp -r ${final.wger-react-components}/* $out/node_modules/@wger-project/react-components/
      # Also copy the compiled CSS
      cp wger/core/static/bootstrap-compiled.css $out/
    '';
  };

  # Main wger package (as library so it can be used with withPackages)
  wger = final.wger-python-packages.buildPythonPackage {
    pname = "wger";
    version = "2.6";
    pyproject = true;

    src = wgerPatchedSrc;

    nativeBuildInputs = with final.wger-python-packages; [
      hatchling
      hatch-vcs
    ];

    propagatedBuildInputs = with final.wger-python-packages; [
      # Core Django
      django
      djangorestframework
      djangorestframework-simplejwt
      django-crispy-forms
      final.wger-python-packages.crispy-bootstrap5
      django-allauth
      fido2
      qrcode
      django-filter
      django-cors-headers
      django-redis
      django-storages

      # Object storage
      boto3

      # Database
      psycopg
      psycopg-pool

      # Async/background tasks
      celery
      redis
      flower
      gevent

      # Media handling
      pillow
      easy-thumbnails
      reportlab

      # Security
      nh3
      final.wger-python-packages.django-recaptcha
      django-axes
      python-ipware

      # API docs
      drf-spectacular
      final.wger-python-packages.drf-spectacular-sidecar

      # wger-specific
      final.wger-python-packages.django-bootstrap-breadcrumbs2
      final.wger-python-packages.django-activity-stream
      django-environ
      django-formtools
      django-prometheus
      django-simple-history
      final.wger-python-packages.django-sortedm2m
      final.wger-python-packages.fontawesomefree

      # Data sources
      final.wger-python-packages.openfoodfacts
      requests

      # Utilities
      icalendar
      invoke
      markdownify
      markdown-it-py
      final.wger-python-packages.lingua-language-detector
      packaging
      tqdm
      tzdata

      # Production server
      gunicorn
    ];

    # Don't try to run tests during build
    doCheck = false;

    # Nixpkgs carries compatible newer releases; retain dependency-presence
    # checks while relaxing only the upstream version constraints.
    pythonRelaxDeps = true;

    # Post install: copy settings and resources
    postInstall = ''
      mkdir -p $out/share/wger
      cp -r $src/wger/locale $out/share/wger/ || true
      cp -r $src/wger/core/static $out/share/wger/ || true
      cp -r $src/wger/core/templates $out/share/wger/ || true

      # Copy settings package to site-packages so it's importable
      cp -r $src/settings $out/${final.python312.sitePackages}/

      # Link node_modules for static files
      ln -s ${final.wger-node-modules}/node_modules $out/${final.python312.sitePackages}/node_modules

      # Copy compiled CSS
      cp ${final.wger-node-modules}/bootstrap-compiled.css $out/${final.python312.sitePackages}/wger/core/static/
    '';

    meta = with final.lib; {
      description = "FLOSS workout, fitness and weight manager/tracker";
      homepage = "https://wger.de/";
      license = licenses.agpl3Plus;
      maintainers = [ ];
    };
  };

  # Wrapper script for running wger with proper settings
  wger-manage = final.writeShellScriptBin "wger-manage" ''
    export PYTHONPATH="${final.wger}/${final.python312.sitePackages}:$PYTHONPATH"
    exec ${final.python312}/bin/python -m wger "$@"
  '';
}

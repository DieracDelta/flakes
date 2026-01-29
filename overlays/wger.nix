# wger Workout Manager overlay - builds from local development source
{ wger-src, wger-react-src }:
final: prev:
let
  python = final.python312;
  pythonPackages = python.pkgs;
in
{
  # Python packages that need to be added or overridden for wger
  wger-python-packages = pythonPackages.overrideScope (pyFinal: pyPrev: {
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

    # crispy-bootstrap5 - may need newer version
    crispy-bootstrap5 = pyPrev.crispy-bootstrap5.overridePythonAttrs (old: rec {
      version = "2025.6";
      src = pyFinal.fetchPypi {
        pname = "crispy_bootstrap5";
        inherit version;
        hash = "sha256-8b3nysB0xlD8gvMXd9Skz9DfJRLGi8QSjyWcddParaQ=";
      };
    });

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
        pyPrev.pyjwt  # Use nixpkgs version to avoid duplicate
        pyFinal.validators
      ];
      pythonImportsCheck = [ "django_email_verification" ];
      doCheck = false;
    };

    # lingua-language-detector - not in nixpkgs (Rust binary, needs platform-specific wheel)
    lingua-language-detector = pyFinal.buildPythonPackage rec {
      pname = "lingua-language-detector";
      version = "2.1.1";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/42/41/22ce56bb34ed8ea418e67ac448f557af3a9a446defb523fb7b85e822e32b/lingua_language_detector-2.1.1-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        hash = "sha256-ajmOSHH+jjL/VxHqq7CevfT4BCDXPl1kamyuBGjHxH4=";
      };

      pythonImportsCheck = [ "lingua" ];
      doCheck = false;
    };

    # openfoodfacts - not in nixpkgs
    openfoodfacts = pyFinal.buildPythonPackage rec {
      pname = "openfoodfacts";
      version = "3.3.0";
      format = "pyproject";

      src = final.fetchFromGitHub {
        owner = "openfoodfacts";
        repo = "openfoodfacts-python";
        rev = "v${version}";
        hash = "sha256-EuFTSjJwdyTJIc1xDYkVfZmDFGcMrjwubwqXmCqz8uQ=";
      };

      nativeBuildInputs = [ pyFinal.poetry-core ];

      propagatedBuildInputs = with pyFinal; [
        requests
        pydantic
        pydantic-settings
        cachetools
        tqdm
        pillow
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

      src = pyFinal.fetchPypi {
        inherit pname version;
        hash = "sha256-M6RnupuamWnL7Xay/WXpShmSjkjw7CsuW7GFUXcDbtI=";
      };

      propagatedBuildInputs = [ pyFinal.django ];
      pythonImportsCheck = [ "actstream" ];
      doCheck = false;
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
  });

  # Build wger-react components from local source
  # This fixes i18n issues when served under a subpath like /wger/
  wger-react-components = final.buildNpmPackage {
    pname = "wger-react-components";
    version = "local";
    src = wger-react-src;
    npmDepsHash = "sha256-VuU+B/qOOuBZAZaghBQht7fGgtxL8x7+hWblfoxqxUs=";

    buildPhase = ''
      npm run build
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
    version = "local";
    src = wger-src;
    npmDepsHash = "sha256-LLZ038XBIfp5hXjrSKsgFu2AxTa5xxp4BuYudUjVl8U=";
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
    version = "local";
    pyproject = true;

    src = wger-src;

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
      django-filter
      django-cors-headers
      django-redis
      django-storages

      # Database
      psycopg

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
      bleach
      final.wger-python-packages.tinycss2  # For bleach[css]
      final.wger-python-packages.django-recaptcha
      django-axes

      # API docs
      drf-spectacular
      final.wger-python-packages.drf-spectacular-sidecar

      # wger-specific
      final.wger-python-packages.django-bootstrap-breadcrumbs2
      final.wger-python-packages.django-email-verification
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
      final.wger-python-packages.lingua-language-detector
      packaging
      tqdm
      tzdata

      # Production server
      gunicorn
    ];

    # Don't try to run tests during build
    doCheck = false;

    # Skip strict version checks - nixpkgs has slightly newer versions
    dontCheckRuntimeDeps = true;

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

# Missing Python packages for Plane API
# Used via pythonPackagesExtensions in the overlay
python-final: python-prev: {

  # Django 4.2 LTS was removed from nixpkgs after EOL (April 2026).
  # Plane pins Django==4.2.30 and doesn't support Django 5 yet.
  # Override `django` so all transitive deps (DRF, django-filter, etc.) use 4.2.
  django_4 = python-final.buildPythonPackage rec {
    pname = "django";
    version = "4.2.30";
    pyproject = true;

    src = python-final.fetchPypi {
      pname = "django";
      inherit version;
      hash = "sha256-Trx6Q044Gdts9LOZ+1s/U2MQow6EhvCLZohoQL6Es3w=";
    };

    build-system = [ python-final.setuptools ];

    dependencies = with python-final; [
      asgiref
      sqlparse
    ];

    doCheck = false;
    pythonImportsCheck = [ "django" ];
  };

  # Pin django to 4.2 so all packages that depend on "django" get 4.2
  django = python-final.django_4;

  # django-filter 25.x requires Django>=5.2; Plane pins 24.2 which supports 4.2
  django-filter = python-prev.django-filter.overridePythonAttrs (old: rec {
    version = "24.2";
    src = python-final.fetchPypi {
      pname = "django-filter";
      inherit version;
      hash = "sha256-SOX8HaPM1soNX5u1UJc1GM6Xek7d6dKooVSn9PC5+W4=";
    };
  });

  scout-apm = python-final.buildPythonPackage rec {
    pname = "scout-apm";
    version = "3.1.0";
    pyproject = true;

    src = python-final.fetchPypi {
      pname = "scout_apm";
      inherit version;
      hash = "sha256-5Xw84E6pwHcu9bD8PQ9z4+4kn146iO8Oevl543DEy+0=";
    };

    build-system = [ python-final.setuptools ];

    dependencies = with python-final; [
      psutil
      urllib3
      certifi
    ];

    # Tests require a running Scout APM service
    doCheck = false;

    pythonImportsCheck = [ "scout_apm" ];
  };

  jsonmodels = python-final.buildPythonPackage rec {
    pname = "jsonmodels";
    version = "2.7.0";
    pyproject = true;

    src = python-final.fetchPypi {
      inherit pname version;
      hash = "sha256-jAGb8b0lKsPkARJ1B9c16g/WzjCSGAK1/Fx2HNQaGLs=";
    };

    build-system = [ python-final.setuptools ];

    dependencies = with python-final; [
      jsonschema
      python-dateutil
    ];

    doCheck = false;

    pythonImportsCheck = [ "jsonmodels" ];
  };

  django-crum = python-final.buildPythonPackage rec {
    pname = "django-crum";
    version = "0.7.9";
    format = "setuptools";

    src = python-final.fetchPypi {
      inherit pname version;
      hash = "sha256-Zem8DwcKZj+vxNnjV/Rf1ObwGDiyCp4vt2cPVwZ1Qog=";
    };

    nativeBuildInputs = [
      python-final.setuptools
    ];

    # Remove setup_requires (pytest-runner/setuptools-twine not needed for build)
    postPatch = ''
      substituteInPlace setup.cfg \
        --replace-fail "setup_requires =" "# setup_requires ="
    '';

    dependencies = with python-final; [
      django_4
    ];

    doCheck = false;

    pythonImportsCheck = [ "crum" ];
  };
}

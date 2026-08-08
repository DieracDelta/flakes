# Missing Python packages for Plane API
# Used via pythonPackagesExtensions in the overlay
python-final: python-prev: {

  # Plane 1.4.0 migrated to Django 5.2 and django-filter 25.x.
  # Keep the whole Python scope on the same Django major so transitive packages
  # do not pull the old 4.2 compatibility stack back into the environment.
  django = python-final.django_5;
  django-filter = python-prev.django-filter;

  # websockets 16.1 has a timing-sensitive BrokenPipeError assertion that fails
  # nondeterministically in the tuned build sandbox (different client/server
  # variants failed on consecutive runs). Runtime imports are still checked by
  # the upstream derivation; skip only its flaky 1,979-test unit phase.
  websockets = python-prev.websockets.overridePythonAttrs (_: {
    doCheck = false;
  });

  scout-apm = python-final.buildPythonPackage rec {
    pname = "scout-apm";
    version = "3.5.3";
    pyproject = true;

    src = python-final.fetchPypi {
      pname = "scout_apm";
      inherit version;
      hash = "sha256-VOV16V9fmpjAlZigkuwD/I11dpB8U8XiBjKj8F4QNHk=";
    };

    build-system = [ python-final.setuptools ];

    dependencies = with python-final; [
      asgiref
      psutil
      urllib3
      certifi
      wrapt
    ];

    # Scout's metadata caps wrapt below 2, but 3.5.3 works with nixpkgs'
    # current wrapt 2.x API and imports successfully.
    pythonRelaxDeps = [ "wrapt" ];

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

  py-key-value-aio = python-final.buildPythonPackage rec {
    pname = "py-key-value-aio";
    version = "0.4.4";
    format = "wheel";

    src = python-final.fetchPypi {
      pname = "py_key_value_aio";
      inherit version format;
      python = "py3";
      dist = "py3";
      hash = "sha256-GOF1ZOyuYbmH+Qn8LNQe4gEshLSx3LjAVc+LS8G/P10=";
    };

    dependencies = with python-final; [
      beartype
      typing-extensions
    ];

    optional-dependencies = with python-final; {
      filetree = [
        aiofile
        anyio
      ];
      keyring = [ keyring ];
      memory = [ cachetools ];
      redis = [ redis ];
    };

    doCheck = false;
    pythonImportsCheck = [ "key_value.aio" ];
  };

  fakeredis = python-final.buildPythonPackage rec {
    pname = "fakeredis";
    version = "2.34.1";
    format = "wheel";

    src = python-final.fetchPypi {
      inherit pname version format;
      python = "py3";
      dist = "py3";
      hash = "sha256-AQfsmdSJE+fuwqXj4kA9G9X4qmSJ0aY0VxuXUonEjxI=";
    };

    dependencies = with python-final; [
      redis
      sortedcontainers
      lupa
    ];

    doCheck = false;
    pythonImportsCheck = [ "fakeredis" ];
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
      django
    ];

    doCheck = false;

    pythonImportsCheck = [ "crum" ];
  };
}

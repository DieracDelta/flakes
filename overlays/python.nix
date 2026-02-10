final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      # Python stuff is finnicky af
      # Handle both old style (set) and new style (finalAttrs function)
      disableCheckArgsSet =
        args:
        let
          existingPrePhases = args.prePhases or [ ];
        in
        args
        // {
          prePhases =
            if builtins.elem "disableChecksPhase" existingPrePhases then
              existingPrePhases
            else
              existingPrePhases ++ [ "disableChecksPhase" ];
          disableChecksPhase = ''
            unset doCheck
            unset doInstallCheck
            # Override Python-specific check phases to be no-ops
            pytestCheckPhase() { :; }
            pythonImportsCheckPhase() { :; }
          '';
        };
      disableCheckArgs =
        args:
        if builtins.isFunction args then
          # New style: buildPythonPackage (finalAttrs: { ... })
          finalAttrs: python-final.disableCheckArgsSet (args finalAttrs)
        else
          # Old style: buildPythonPackage { ... }
          python-final.disableCheckArgsSet args;

      # Wrap buildPythonPackage to disable checks - use lib.setFunctionArgs to preserve function metadata
      buildPythonPackage =
        let
          orig = python-prev.buildPythonPackage;
          wrapped = args: orig (python-final.disableCheckArgs args);
        in
        final.lib.setFunctionArgs wrapped (final.lib.functionArgs orig) // { inherit (orig) override; };
      buildPythonApplication =
        let
          orig = python-prev.buildPythonApplication;
          wrapped = args: orig (python-final.disableCheckArgs args);
        in
        final.lib.setFunctionArgs wrapped (final.lib.functionArgs orig) // { inherit (orig) override; };

      # Package-specific fixes
      psycopg = python-prev.psycopg.overridePythonAttrs (oldAttrs: {
        propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [ python-final.psycopg-pool ];
      });

      mutatormath = python-prev.mutatormath.overridePythonAttrs (old: {
        catchConflicts = false;
      });

      jeepney = python-prev.jeepney.overridePythonAttrs (old: {
        pythonImportsCheck = [ "jeepney" ];
      });

      fontparts = python-prev.fontparts.overridePythonAttrs (old: {
        catchConflicts = false;
        dontCheckRuntimeDeps = true;
      });

      ufoprocessor = python-prev.ufoprocessor.overridePythonAttrs (old: {
        catchConflicts = false;
        dontCheckRuntimeDeps = true;
      });

      afdko = python-prev.afdko.overridePythonAttrs (old: {
        dontCheckRuntimeDeps = true;
        catchConflicts = false;
      });

      sqlalchemy-utils = python-prev.sqlalchemy-utils.overridePythonAttrs (old: rec {
        version = "0.41.2";
        src = final.fetchFromGitHub {
          owner = "kvesteri";
          repo = "sqlalchemy-utils";
          rev = version;
          hash = "sha256-jC8onlCiuzpMlJ3EzpzCnQ128xpkLzrZEuGWQv7pvVE=";
        };
      });

      # PyICU: Use PyPI source instead of GitLab (which returns 502 errors)
      pyicu = python-prev.pyicu.overridePythonAttrs (old: rec {
        version = "2.16";
        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/11/c3/8d558b30deb33eb583c0bcae3e64d6db8316b69461a04bb9db5ff63d3f6e/pyicu-2.16.tar.gz";
          hash = "sha256-QrOoBi47I+knynJ+a14XMNhscCeYNOSIcVKJXS6wEtk=";
        };
      });
    })
  ];
}

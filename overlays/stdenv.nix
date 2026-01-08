# literally nuke all testphases because we ball
final: prev: {
  stdenv = prev.stdenv // {
    mkDerivation =
      fnOrAttrs:
      let
        disableChecks = ''
          unset doCheck
          unset doInstallCheck
        '';
        prependToPhase =
          phase:
          if builtins.isList phase then
            [ disableChecks ] ++ phase
          else if builtins.isString phase then
            disableChecks + phase
          else
            disableChecks;
        addDisablePhase =
          attrs:
          let
            existingPrePhases = attrs.prePhases or [ ];
          in
          attrs
          // {
            prePhases =
              if builtins.elem "disableChecksPhase" existingPrePhases then
                existingPrePhases
              else
                existingPrePhases ++ [ "disableChecksPhase" ];
            disableChecksPhase = disableChecks;
            preCheck = prependToPhase (attrs.preCheck or null);
            preInstallCheck = prependToPhase (attrs.preInstallCheck or null);
          };
      in
      if builtins.isFunction fnOrAttrs then
        prev.stdenv.mkDerivation (attrs: addDisablePhase (fnOrAttrs attrs))
      else
        prev.stdenv.mkDerivation (addDisablePhase fnOrAttrs);
  };
}

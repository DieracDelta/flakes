# Global stdenv overlay to disable doCheck and doInstallCheck for all derivations
# This significantly speeds up builds by skipping test suites
final: prev: {
  stdenv = prev.stdenv // {
    mkDerivation =
      fnOrAttrs:
      let
        disableChecks = ''
          unset doCheck
          unset doInstallCheck
        '';
        # Prepend disableChecks to a phase, handling string, list, or missing cases
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
            # Also unset in preCheck and preInstallCheck for builders that set these later
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

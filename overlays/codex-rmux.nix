final: prev:
{
  codex = final.runCommand "${prev.codex.name}-rmux" { nativeBuildInputs = [ final.makeWrapper ]; } ''
    mkdir -p $out/bin
    for binary in ${prev.codex}/bin/*; do
      ln -s "$binary" "$out/bin/$(basename "$binary")"
    done

    rm -f $out/bin/codex
    makeWrapper ${prev.codex}/bin/codex $out/bin/codex \
      --run 'if [ -n "''${RMUX-}" ]; then export TMUX="''${TMUX:-$RMUX}"; export TMUX_PANE="''${TMUX_PANE:-''${RMUX_PANE:-%0}}"; fi'
  '';
}

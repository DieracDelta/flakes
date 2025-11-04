if test -n "$GHOSTTY_RESOURCES_DIR"
    source "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
end

if status is-interactive
    # Raise CPU scheduling priority
    renice -n -10 -p $fish_pid 2>/dev/null
    # Raise IO priority
    ionice -c2 -n0 -p $fish_pid 2>/dev/null
end

function nn --description 'launch nvim, then boost its priority'
      /home/jrestivo/dev/vimconfig/result/bin/nvim  $argv &; set pid $last_pid
      renice -n -10 -p $pid
      ionice -c2 -n0 -p $pid
      fg $pid
end

set os (uname)

ssh-agent -c | source -
if test $os = "Darwin"
  ssh-add ~/.ssh/id_ed25519
  # ssh-add ~/.ssh/id_rsa_old
  fish_add_path /run/current-system/sw/bin
  fish_add_path /opt/homebrew/bin
  fish_add_path /Users/jrestivo/dev/tdf/target/release/
  export EDITOR="/Users/jrestivo/dev/vimconfig/result/bin/nvim"
else if test $os = "Linux"
  ssh-add ~/.ssh/id_rsa
  export EDITOR="/home/jrestivo/dev/vimconfig/result/bin/nvim"
else
    echo "Unknown OS: $os"
end

export ET_NO_TELEMETRY="y"

export _ZO_MAXAGE=10000000
export _ZO_RESOLVE_SYMLINKS=1

function last_history_item
    echo $history[1]
end
abbr -a !! --position anywhere --function last_history_item

abbr -a esc '/usr/bin/env'
abbr -a nd 'nix develop -c fish'
abbr --position anywhere --add \.\.\. '../../'
abbr --position anywhere --add \.\.\.\. '../../../'
abbr --position anywhere --add \.\.\.\.\. '../../../../'
abbr --position anywhere --add \.\.\.\.\.\. '../../../../../'


fish_vi_key_bindings
set -U fish_greeting

eval "$(starship init fish)"
zoxide init fish | source

export NIX_BUILD_SHELL="bash"

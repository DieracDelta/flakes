if test -n "$GHOSTTY_RESOURCES_DIR"
    source "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
end

set os (uname)

if test $os = "Darwin"
  fish_add_path /run/current-system/sw/bin
  fish_add_path /opt/homebrew/bin
  export EDITOR="/Users/jrestivo/dev/vimconfig/result/bin/nvim"
else if test $os = "Linux"
  export EDITOR="/home/jrestivo/dev/vimconfig/result/bin/nvim"
else
    echo "Unknown OS: $os"
end

export _ZO_MAXAGE=10000000
export _ZO_RESOLVE_SYMLINKS=1

ssh-agent -c | source -
ssh-add ~/.ssh/id_rsa
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

export EDITOR="vi"
export _ZO_MAXAGE=10000000
export _ZO_RESOLVE_SYMLINKS=1

ssh-agent -c | source -
ssh-add ~/.ssh/id_rsa    # Replace id_rsa with the filename of your SSH private key
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

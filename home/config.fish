if test -n "$GHOSTTY_RESOURCES_DIR"
    source "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
end

function nn --description 'launch nvim with priority boosting where available'
    set OS (uname)

    if test "$OS" = "Darwin"
        /Users/jrestivo/dev/vimconfig/result/bin/nvim $argv &; set pid $last_pid

        if type -q renice
            sudo -n renice -n -10 -p $pid 2>/dev/null
        end

        fg

    else if test "$OS" = "Linux"
        /home/jrestivo/dev/vimconfig/result/bin/nvim $argv &; set pid $last_pid

        if type -q renice
            sudo -n renice -n -10 -p $pid 2>/dev/null
        end

        if type -q ionice
            sudo -n ionice -c2 -n0 -p $pid 2>/dev/null
        end

        fg

    else
        echo "nn: unsupported OS: $OS" >&2
    end
end

set os (uname)

function __add_ssh_key_once --argument-names key_path
    test -r "$key_path"; or return

    set -l pub_path "$key_path.pub"
    if test -r "$pub_path"
        set -l fingerprint (ssh-keygen -lf "$pub_path" 2>/dev/null | awk '{print $2}')
        if test -n "$fingerprint"; and ssh-add -l 2>/dev/null | string match -q "*$fingerprint*"
            return
        end
    end

    ssh-add -q "$key_path"
end

function __use_shared_ssh_agent
    set -l gcr_sock "$XDG_RUNTIME_DIR/gcr/ssh"
    set -l fallback_sock "$XDG_RUNTIME_DIR/ssh-agent/socket"

    if test -n "$XDG_RUNTIME_DIR"; and test -S "$gcr_sock"
        set -gx SSH_AUTH_SOCK "$gcr_sock"
        set -e SSH_AGENT_PID
        return
    end

    if set -q SSH_AUTH_SOCK; and test -S "$SSH_AUTH_SOCK"; and ssh-add -l >/dev/null 2>&1
        return
    end

    if test -n "$XDG_RUNTIME_DIR"
        mkdir -p (dirname "$fallback_sock")
        if test -S "$fallback_sock"; and env SSH_AUTH_SOCK="$fallback_sock" ssh-add -l >/dev/null 2>&1
            set -gx SSH_AUTH_SOCK "$fallback_sock"
            set -e SSH_AGENT_PID
            return
        end

        rm -f "$fallback_sock"
        ssh-agent -a "$fallback_sock" -c | source -
    end
end

if test $os = "Darwin"
  if not set -q SSH_AUTH_SOCK; or not test -S "$SSH_AUTH_SOCK"
    ssh-agent -c | source -
  end
  ssh-add ~/.ssh/id_ed25519
  # ssh-add ~/.ssh/id_rsa_old
  fish_add_path /run/current-system/sw/bin
  fish_add_path /opt/homebrew/bin
  fish_add_path /Users/jrestivo/dev/tdf/target/release/
  export EDITOR="/Users/jrestivo/dev/vimconfig/result/bin/nvim"
else if test $os = "Linux"
  set -gx FORGEJO_URL "https://office-desktop.tail5ca7.ts.net/forgejo"
  set -gx FORGEJO_URL http://127.0.0.1:3010
  set -gx FORGEJO_ACCESS_TOKEN (command cat /home/jrestivo/FOREJO_TOKEN | string trim)
  set -gx PLANE_API_KEY (command cat /home/jrestivo/PLANE_TOKEN | string trim)


  __use_shared_ssh_agent
  __add_ssh_key_once ~/.ssh/id_rsa
  export EDITOR="/home/jrestivo/dev/vimconfig/result/bin/nvim"
else
    echo "Unknown OS: $os"
end

export ET_NO_TELEMETRY="y"

export _ZO_MAXAGE=10000000
export _ZO_RESOLVE_SYMLINKS=1
export GH_TELEMETRY=false
export DO_NOT_TRACK=true


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
abbr --position anywhere --add \.\.\.\.\.\.\. '../../../../../../'


fish_vi_key_bindings
set -U fish_greeting

export NIX_BUILD_SHELL="bash"

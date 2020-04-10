#!/usr/bin/env bash

zathura_tmp=$(mktemp -d)
[ -f $XDG_CONFIG_HOME/zathura/zathurarc ] && cat "$XDG_CONFIG_HOME/zathura/zathurarc" >> "$zathura_tmp/zathurarc" || \
[ -f $HOME/.config/zathura/zathurarc ] && cat "$HOME/.config/zathura/zathurarc" >> "$zathura_tmp/zathurarc"
gen_rc.sh >> "$zathura_tmp/zathurarc"
GDK_BACKEND=x11 zathura --config-dir="$zathura_tmp" "$@" & disown && exit

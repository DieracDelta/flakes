#/usr/bin/env bash
/run/current-system/sw/bin/emacsclient -c --no-wait --socket=$(lsof -c emacs | grep server | grep -E -o '[^[:blank:]]*$' | tail -n 1)

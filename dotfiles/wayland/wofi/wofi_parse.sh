#!/usr/bin/env bash
ret=$(tac /tmp/notif | wofi --show dmenu -k /dev/null )
size=${#ret}
if [ $size -gt 0 ]; then
        echo $ret | wl-copy -n
        echo "" > /tmp/notif
fi

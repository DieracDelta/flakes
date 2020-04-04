#!/usr/bin/env bash
ret=$(tac /tmp/notif | wofi --show dmenu -k /dev/null --style /etc/wofi/style.css --conf /etc/wofi/config)
size=${#ret}
if [ $size -gt 0 ]; then
        echo $ret | wl-copy -n
        echo "" > /tmp/notif
fi

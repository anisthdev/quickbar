#!/bin/sh
# Swap between waybar and quickbar, whichever is running now
dir=$(dirname "$(realpath "$0")")

if pgrep -x waybar >/dev/null; then
    pkill -x waybar
    qs -p "$dir" -d
else
    qs kill -p "$dir"
    setsid -f waybar >/dev/null 2>&1
fi

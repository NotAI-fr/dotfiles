#!/usr/bin/env bash
set -u

LOCAL_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/i3/local.env"
[[ -r "$LOCAL_ENV" ]] && source "$LOCAL_ENV"
EXTERNAL_OUTPUT="${EXTERNAL_OUTPUT:-HDMI-2}"
STATE="$HOME/.cache/monitor_brightness"

current=$(cat "$STATE" 2>/dev/null || echo "1.0")
new=$(awk "BEGIN {
    v=$current+0.05;
    if (v>1.0) v=1.0;
    print v
}")

mkdir -p "$(dirname "$STATE")"
printf '%s
' "$new" > "$STATE"
xrandr --output "$EXTERNAL_OUTPUT" --brightness "$new"
percent=$(awk "BEGIN { printf "%d", $new*100 }")

notify-send \
    -a "OSD" \
    -u low \
    -h string:x-dunst-stack-tag:brightness \
    -h int:value:"$percent" \
    "Brightness" \
    "$percent%"

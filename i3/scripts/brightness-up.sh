#!/bin/bash

STATE="$HOME/.cache/monitor_brightness"

current=$(cat "$STATE" 2>/dev/null || echo "1.0")

new=$(awk "BEGIN {
    v=$current+0.05;
    if (v>1.0) v=1.0;
    print v
}")

echo "$new" > "$STATE"

xrandr --output HDMI-2 --brightness "$new"

percent=$(awk "BEGIN { printf \"%d\", $new*100 }")

notify-send \
    -a "OSD" \
    -u low \
    -h string:x-dunst-stack-tag:brightness \
    -h int:value:$percent \
    "Brightness" \
    "$percent%"

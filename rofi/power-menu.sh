#!/usr/bin/env bash

# Check whether picom is running to choose the gamemode icon.
if pgrep -x "picom" >/dev/null; then
    GAMEMODE_ICON="󰾆"
else
    GAMEMODE_ICON="󰓅"
fi

# The thin space after the gamemode glyph compensates for its slightly
# right-heavy visual bounds in Rofi without changing the other icons.
GAMEMODE_DISPLAY="${GAMEMODE_ICON}"$'\u2009'

# Ask Rofi to return the selected row index rather than the displayed text.
# This lets the display-only spacing above remain separate from the action.
chosen=$(
    printf '%s\n' \
        "󰐥" \
        "󰜉" \
        "󰤄" \
        "󰌾" \
        "󰍃" \
        "$GAMEMODE_DISPLAY" |
    rofi -dmenu -i -no-custom -format i -p "Power" \
        -theme-str '
window {
    width: 630px;
    border-radius: 12px;
    padding: 10px;
}

inputbar {
    enabled: false;
}

listview {
    columns: 6;
    lines: 1;
    spacing: 12px;
    cycle: true;
    scrollbar: false;
    fixed-columns: true;
}

element {
    orientation: vertical;
    children: [ "element-text" ];
    padding: 18px;
    border-radius: 8px;
}

element-text {
    font: "JetBrainsMono Nerd Font 28";
    expand: true;
    horizontal-align: 0.5;
    vertical-align: 0.5;
    margin: 0px;
    padding: 0px;
}
'
)

# -format i returns a zero-based row index.
case "$chosen" in
    0) poweroff ;;
    1) reboot ;;
    2) systemctl suspend ;;
    3) betterlockscreen -l blur ;;
    4) i3-msg exit ;;
    5)
        if pgrep -x "picom" >/dev/null; then
            killall picom
        else
            picom -b
        fi
        ;;
esac

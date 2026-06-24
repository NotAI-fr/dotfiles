#!/usr/bin/env bash

# Pass only the pure Nerd Font icons separated by newlines
ICON_LIST="󰐥\n󰜉\n󰤄\n󰌾\n󰍃"

# Launch rofi with a true 5-column grid layout row and forced text centering
chosen=$(echo -e "$ICON_LIST" | rofi -dmenu -i -p "Power" \
  -theme-str '
    window { width: 520px; border-radius: 12px; padding: 10px; }
    inputbar { enabled: false; }
    listview { columns: 5; lines: 1; fixed-columns: true; spacing: 12px; cycle: true; }
    element { padding: 18px 0px; border-radius: 8px; children: [ "element-text" ]; }
    element-text { font: "JetBrains Mono Nerd Font 28"; margin: 0px; padding: 0px; horizontal-align: 0.5; vertical-align: 0.5; }
  ')

# Execute actions based on the pure icon returned
case "$chosen" in
    "󰐥")
        poweroff
        ;;
    "󰜉")
        reboot
        ;;
    "󰤄")
        systemctl suspend
        ;;
    "󰌾")
        betterlockscreen -l blur
        ;;
    "󰍃")
        i3-msg exit
        ;;
esac

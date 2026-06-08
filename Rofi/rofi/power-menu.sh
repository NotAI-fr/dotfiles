#!/usr/bin/env bash
chosen=$(echo -e "Shutdown\nReboot\nExit i3" | rofi -dmenu -theme ~/.config/rofi/mono.rasi -p "Power:")
case "$chosen" in
    Shutdown) poweroff ;;
    Reboot) reboot ;;
    "Exit i3") i3-msg exit ;;
esac

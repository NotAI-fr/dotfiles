#!/usr/bin/env bash

chosen=$(printf "󰐥 Shutdown\n󰜉 Reboot\n󰤄 Suspend\n󰌾 Lock\n󰍃 Logout\n" | rofi -dmenu -p "Power")

case "$chosen" in
    "󰐥 Shutdown")
        poweroff
        ;;
    "󰜉 Reboot")
        reboot
        ;;
    "󰤄 Suspend")
        systemctl suspend
        ;;
    "󰌾 Lock")
        betterlockscreen -l
        ;;
    "󰍃 Logout")
        i3-msg exit
        ;;
esac

#!/usr/bin/env bash
# Quick toggle script for Bluetooth via Rofi

options="Toggle Power\nConnect Device\nDisconnect Device"
chosen=$(echo -e "$options" | rofi -dmenu -theme ~/.config/rofi/mono.rasi -p "Bluetooth:")

case "$chosen" in
    "Toggle Power")
        if bluetoothctl show | grep -q "Powered: yes"; then
            bluetoothctl power off
        else
            bluetoothctl power on
        fi
        ;;
    "Connect Device")
        # List paired devices and pick one to connect
        device=$(bluetoothctl devices | rofi -dmenu -theme ~/.config/rofi/mono.rasi -p "Select Device:")
        mac=$(echo "$device" | awk '{print $2}')
        if [ -n "$mac" ]; then bluetoothctl connect "$mac"; fi
        ;;
    "Disconnect Device")
        device=$(bluetoothctl devices | rofi -dmenu -theme ~/.config/rofi/mono.rasi -p "Disconnect:")
        mac=$(echo "$device" | awk '{print $2}')
        if [ -n "$mac" ]; then bluetoothctl disconnect "$mac"; fi
        ;;
esac

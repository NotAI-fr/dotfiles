#!/usr/bin/env bash

# Check current Wi-Fi status
wifi_status=$(nmcli radio wifi)

if [ "$wifi_status" = "disabled" ]; then
    options="Toggle Wi-Fi: ON"
else
    options="Toggle Wi-Fi: OFF\nConnect to Network"
fi

# Present initial menu
chosen=$(echo -e "$options" | rofi -dmenu -theme ~/.config/rofi/mono.rasi -p "Wi-Fi:")

case "$chosen" in
    "Toggle Wi-Fi: ON")
        nmcli radio wifi on
        dunstify "Wi-Fi Enabled"
        ;;
    "Toggle Wi-Fi: OFF")
        nmcli radio wifi off
        dunstify "Wi-Fi Disabled"
        ;;
    "Connect to Network")
        # Send a quick non-blocking notification that we are scanning airwaves
        dunstify "Scanning for networks..." -t 2000

        # Fetch available SSIDs, filter out blanks and duplicates
        networks=$(nmcli --fields SSID dev wifi list | sed '1d' | grep -v '^\s*$' | sort -u)

        # Select target SSID
        ssid_selection=$(echo -e "$networks" | rofi -dmenu -theme ~/.config/rofi/mono.rasi -p "Select SSID:")

        if [ -n "$ssid_selection" ]; then
            # Prompt securely for password inside Rofi
            password=$(rofi -dmenu -password -theme ~/.config/rofi/mono.rasi -p "Enter Password (Leave empty if open):")

            if [ -n "$password" ]; then
                # Attempt connection with passphrase
                if nmcli dev wifi connect "$ssid_selection" password "$password"; then
                    dunstify "Connected to $ssid_selection"
                else
                    dunstify "Connection Failed"
                fi
            else
                # Attempt open connection
                if nmcli dev wifi connect "$ssid_selection"; then
                    dunstify "Connected to $ssid_selection"
                else
                    dunstify "Connection Failed"
                fi
            fi
        fi
        ;;
esac

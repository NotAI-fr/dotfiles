#!/bin/bash

# Fetch history and normalize it into a flat array of notification objects
HISTORY_JSON=$(dunstctl history | jq '[.. | objects | select(has("appname"))]')

# Check if we actually got any notifications
if [ "$(echo "$HISTORY_JSON" | jq 'length')" -eq 0 ]; then
    rofi -e "No notifications in history."
    exit 0
fi

# Generate rows for Rofi using flexible fallback paths for fields
NOTIF_ROWS=$(echo "$HISTORY_JSON" | jq -r '
  to_entries[] |
  "[\(.key)] \(.value.appname.data // .value.appname // "Unknown"): \(.value.summary.data // .value.summary // "No Title")"
')

# Show the list in Rofi
SELECTION=$(echo "$NOTIF_ROWS" | rofi -dmenu -p "Notification History" -i -l 10)

if [ -n "$SELECTION" ]; then
    # Extract the index number from the bracketed row (e.g., "[2]" -> "2")
    INDEX=$(echo "$SELECTION" | grep -oP '^\[\d+\]' | tr -d '[]')

    if [ -z "$INDEX" ]; then
        exit 0
    fi

    # Extract fields with bulletproof fallbacks to handle varying Dunst formats
    APP=$(echo "$HISTORY_JSON" | jq -r ".[$INDEX] | .appname.data // .appname // \"Unknown\"")
    SUMMARY=$(echo "$HISTORY_JSON" | jq -r ".[$INDEX] | .summary.data // .summary // \"No Title\"")
    BODY=$(echo "$HISTORY_JSON" | jq -r ".[$INDEX] | .body.data // .body // \"\"" | sed 's/<[^>]*>//g')

    # Format the details block for the sub-menu message pane
    DETAILS="<b>App:</b> $APP\n<b>Title:</b> $SUMMARY\n\n$BODY"

    # Show actions menu with the details injected into the message area
    ACTION=$(echo -e "Clear this notification\nClear all history\nBack" | rofi -dmenu -p "Actions" -mesg "$DETAILS" -i)

    case "$ACTION" in
        "Clear this notification")
            ID=$(echo "$HISTORY_JSON" | jq -r ".[$INDEX] | .id.data // .id")
            if [ "$ID" != "null" ] && [ -n "$ID" ]; then
                dunstctl history-rm "$ID"
            fi
            ;;
        "Clear all history")
            dunstctl history-clear
            ;;
        *)
            exit 0
            ;;
    esac
fi

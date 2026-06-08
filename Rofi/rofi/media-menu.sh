#!/usr/bin/env bash

# Brutalist Media Dropdown (playerctl + rofi)
MONO_THEME="$HOME/.config/rofi/mono.rasi"

# 1. Fetch current playback status and player
STATUS=$(playerctl status 2>/dev/null || echo "No Active Player")
ACTIVE_PLAYER=$(playerctl -l 2>/dev/null | head -n 1 || echo "---")
TITLE=$(playerctl metadata --format '{{ title }}' 2>/dev/null | cut -c 1-30 || echo "No Song")

# 2. Define menu options based on status
if [ "$STATUS" = "Playing" ]; then
    ACTION="Pause"
elif [ "$STATUS" = "Paused" ]; then
    ACTION="Play"
else
    # No player or stopped
    dunstify -u critical "No active media player found."
    exit 1
fi

# 3. Present brutalist menu via Rofi
OPTIONS=$(echo -e " $ACTION\n󰒭 Next Track\n󰒮 Prev Track\n󰓛 Stop\n󰓃 Select Player" | rofi -dmenu -theme "$MONO_THEME" -p "$TITLE ($STATUS):")

# 4. Execute commands based on selection
case "$OPTIONS" in
    *"Play"*) playerctl play-pause ;;
    *"Pause"*) playerctl play-pause ;;
    *"Next"*) playerctl next ;;
    *"Prev"*) playerctl previous ;;
    *"Stop"*) playerctl stop ;;
    *"Select Player"*)
        PLAYERS=$(playerctl -l 2>/dev/null | sort -u)
        SELECTED_PLAYER=$(echo -e "$PLAYERS" | rofi -dmenu -theme "$MONO_THEME" -p "Select Player:")
        if [ -n "$SELECTED_PLAYER" ]; then
            dunstify "Now controlling: $SELECTED_PLAYER"
        fi
        ;;
esac

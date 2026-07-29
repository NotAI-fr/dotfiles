#!/usr/bin/env bash

NOTIFIER="$HOME/.config/polybar/playing-notify.sh"

while true; do
    playerctl --follow metadata mpris:trackid 2>/dev/null |
    while IFS= read -r track; do
        # Playerctl prints an empty line when no player is available.
        [[ -n "$track" ]] || continue

        sleep 0.3
        "$NOTIFIER"
    done

    # Restart playerctl if the player/browser closes.
    sleep 2
done

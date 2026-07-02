#!/usr/bin/env bash

PAUSED=$(dunstctl is-paused)
WAITING=$(dunstctl count waiting)
HISTORY=$(dunstctl count history)

# Add both queues together to get the total number of unseen/missed alerts
TOTAL=$((WAITING + HISTORY))

if [ "$PAUSED" == "true" ]; then
    if [ "$TOTAL" -gt 0 ]; then
        # DND is ON, but you have missed notifications
        echo "󰂛 $TOTAL"
    else
        # DND is ON, 0 missed
        echo "󰂛"
    fi
elif [ "$TOTAL" -gt 0 ]; then
    # DND is OFF, missed notifications in history
    echo "󱅫 $TOTAL"
else
    # Normal state, zero missed
    echo "󰂚 "
fi

#!/bin/bash

# Only look at the first active player
status=$(playerctl status 2>/dev/null | head -n 1)

if [[ -z "$status" || "$status" == "Stopped" ]]; then
    echo " "
else
    # Output only one track
    playerctl metadata --format '{{ title }} - {{ artist }}' 2>/dev/null | head -n 1
fi

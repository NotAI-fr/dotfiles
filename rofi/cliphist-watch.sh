#!/usr/bin/env bash

while true; do
    clipnotify -s clipboard || {
        sleep 1
        continue
    }

    xclip -selection clipboard -o 2>/dev/null | cliphist store
done

#!/usr/bin/env bash

choice=$(
    {
        printf 'CLEAR\t Clear clipboard history\n'
        cliphist list
    } | rofi -dmenu -p Clipboard -display-columns 2
)

[[ -z "$choice" ]] && exit 0

if [[ "$choice" == CLEAR$'\t'* ]]; then
    cliphist wipe
else
    printf '%s\n' "$choice" | cliphist decode | xclip -selection clipboard
fi

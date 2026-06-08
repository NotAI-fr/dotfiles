#!/usr/bin/env bash

# Function to parse i3 workspaces and generate brutalist formatting tags
print_workspaces() {
    focused=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).name')
    out=""

    for i in 1 2 3 4 5; do
        if [ "$i" = "$focused" ]; then
            # Inverted block colors for active workspace
            out="${out}%{A1:i3-msg workspace $i:}%{F#000000}%{B#ffffff} $i %{B-}%{F-}%{A} "
        else
            # Dimmed text for inactive/empty persistent workspaces
            out="${out}%{A1:i3-msg workspace $i:}%{F#555555} $i %{F-}%{A} "
        fi
    done
    echo "$out"
}

# Run once on startup
print_workspaces

# Tail and listen to i3 workspace change events reactively
i3-msg -t subscribe '[ "workspace" ]' 2>/dev/null | while read -r event; do
    print_workspaces
done

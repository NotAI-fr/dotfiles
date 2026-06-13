#!/usr/bin/env bash

print_workspaces() {
    # Extract the name of the currently focused workspace
    focused=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).name')
    out=""

    for i in 1 2 3 4 5; do
        if [ "$i" = "$focused" ]; then
            # Focused: Underlined and colored with your main brutalist accent (#D3D3D3)
            out="${out}%{A1:i3-msg workspace $i:}%{u#D3D3D3}%{+u}%{F#D3D3D3}$i%{-u}%{F-}%{A} "
        else
            # Unfocused: Muted using your exact alt grey (#555555)
            out="${out}%{A1:i3-msg workspace $i:}%{F#555555}$i%{F-}%{A} "
        fi
    done

    echo "$out"
}

print_workspaces

# Keep running and listen for workspace switches to trigger a redraw
i3-msg -t subscribe '[ "workspace" ]' 2>/dev/null | while read -r _; do
    print_workspaces
done

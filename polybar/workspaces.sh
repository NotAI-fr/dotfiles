#!/usr/bin/env bash

print_workspaces() {
    focused=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).name')
    out=""

    for i in 1 2 3 4 5; do
        if [ "$i" = "$focused" ]; then
            out="${out}%{A1:i3-msg workspace $i:}%{u#ffffff}%{+u}$i%{-u}%{A} "
        else
            out="${out}%{A1:i3-msg workspace $i:}%{F#888888}$i%{F-}%{A} "
        fi
    done

    echo "$out"
}

print_workspaces

i3-msg -t subscribe '[ "workspace" ]' 2>/dev/null | while read -r _; do
    print_workspaces
done

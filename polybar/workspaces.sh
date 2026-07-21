#!/usr/bin/env bash

# Read the active theme's existing Polybar palette. Polybar config variables are
# not shell variables, so a custom script cannot use ${colors.*} directly.
load_colors() {
    local theme palette pointer include key value

    FG="#FFFFFF"
    ALT="#CBA6F7"
    INACTIVE="#7F849C"

    if [[ -r "$HOME/.config/.current_theme" ]]; then
        IFS= read -r theme < "$HOME/.config/.current_theme"
        palette="$HOME/.config/colorschemes/$theme/polybar/$theme.ini"
    fi

    # Fallback: follow the include in Polybar's currently active colors.ini.
    if [[ ! -r "${palette:-}" ]]; then
        pointer="$HOME/.config/polybar/colors.ini"
        if [[ -r "$pointer" ]]; then
            include=$(awk -F= '
                /^[[:space:]]*include-file[[:space:]]*=/ {
                    sub(/^[^=]*=[[:space:]]*/, "")
                    sub(/[[:space:]]*$/, "")
                    print
                    exit
                }
            ' "$pointer")

            if [[ "$include" == "~/"* ]]; then
                include="$HOME/${include#~/}"
            fi
            palette="$include"
        fi
    fi

    [[ -r "${palette:-}" ]] || return 0

    while IFS='=' read -r key value; do
        key="${key//[[:space:]]/}"
        value="${value//[[:space:]]/}"

        case "$key" in
            fg)     FG="$value" ;;
            alt)    ALT="$value" ;;
            border) INACTIVE="$value" ;;
        esac
    done < "$palette"
}

print_workspaces() {
    local focused out i
    load_colors

    focused=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused == true).name')
    out=""

    for i in 1 2 3 4 5; do
        if [[ "$i" == "$focused" ]]; then
            # Active: theme foreground with the theme accent underline.
            out+="%{A1:i3-msg workspace $i:}%{F$FG}%{u$ALT}%{+u}$i%{-u}%{F-}%{A} "
        else
            # Inactive: the theme's existing border/muted color.
            out+="%{A1:i3-msg workspace $i:}%{F$INACTIVE}$i%{F-}%{A} "
        fi
    done

    printf '%s\n' "$out"
}

print_workspaces

i3-msg -t subscribe '["workspace"]' 2>/dev/null | while read -r _; do
    print_workspaces
done

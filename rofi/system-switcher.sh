#!/usr/bin/env bash

# =====================================================================
# SYSTEM SWITCHER - Main menu for themes and layouts
# =====================================================================
# Unified menu to switch between:
# - Color themes
# - Polybar layouts

MAIN_MENU=""
MAIN_MENU+="<span foreground='#a7c080'>󰉼</span>  Change Theme\n"
MAIN_MENU+="<span foreground='#cba6f7'>󰦕</span>  Change Bar Layout"

CHOICE=$(echo -e "$MAIN_MENU" | rofi -dmenu -markup-rows -p "⚙️  System Settings" -i -theme-str 'entry { placeholder: "Choose option ⚙️"; }')

if [[ -z "$CHOICE" ]]; then
    exit 0
fi

case "$CHOICE" in
    *"Theme"*)
        ~/.config/rofi/theme-switcher.sh
        ;;
    *"Layout"*)
        ~/.config/rofi/bar-layout-switcher.sh
        ;;
esac

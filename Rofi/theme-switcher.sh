#!/usr/bin/env bash

# 1. Define Paths
COLORS_DIR="$HOME/.config/colors"
WALLPAPER_BASE_DIR="$HOME/Pictures/walls"

# 2. Get the list of themes
themes=$(ls "$COLORS_DIR/i3")

# 3. Prompt Rofi to select a theme
chosen=$(echo "$themes" | rofi -dmenu -p "Select Theme" -config ~/.config/rofi/config.rasi)

# Exit if you press Escape or don't choose anything
if [ -z "$chosen" ]; then
    exit 0
fi
# 4. Map each theme to its specific categorized wallpaper
# CHANGE THE CATEGORY FOLDERS AND IMAGE NAMES TO MATCH YOUR ACTUAL FILES
case "$chosen" in
    "monochrome")
        WALLPAPER="$WALLPAPER_BASE_DIR/monochrome/black_and_white_clouds.jpg"
    "everforest")
        WALLPAPER="$WALLPAPER_BASE_DIR/everforest/woman_painting_ghibli.jpg"
        ;;
    "gruvbox")
        WALLPAPER="$WALLPAPER_BASE_DIR/gruvbox/ghibli_gruvbox.jpg"
        ;;
    *)
        WALLPAPER=""
        ;;
esac

# 5. Force update the symlinks for all 4 applications
ln -sf "$COLORS_DIR/i3/$chosen" "$HOME/.config/i3/current-theme"
ln -sf "$COLORS_DIR/polybar/$chosen.ini" "$HOME/.config/polybar/current-theme.ini"
ln -sf "$COLORS_DIR/kitty/$chosen.conf" "$HOME/.config/kitty/current-theme.conf"
ln -sf "$COLORS_DIR/rofi/$chosen.rasi" "$HOME/.config/rofi/current-theme.rasi"

# 6. Apply the wallpaper via feh
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    feh --bg-fill "$WALLPAPER"
else
    # Fallback if the path above was wrong: find the first image in that directory
    feh --bg-fill "$(find "$WALLPAPER_BASE_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | shuf -n 1)"
fi

# 7. Reload the Applications
i3-msg reload > /dev/null 2>&1

# If Polybar isn't running, start it fresh; otherwise, restart it
if ! polybar-msg cmd restart > /dev/null 2>&1; then
    killall -q polybar
    polybar main &
fi

# Hot-reload kitty instances
killall -SIGUSR1 kitty

#!/usr/bin/env bash

# Base wallpaper directory
WALLPAPER_BASE="$HOME/Pictures/Walls"
CURRENT_THEME_FILE="$HOME/.config/.current_theme"

# Integrity Check: Does the base folder exist?
if [ ! -d "$WALLPAPER_BASE" ]; then
    mkdir -p "$WALLPAPER_BASE"
    dunstify "Created ~/Wallpapers folder. Add subfolders here!"
    exit 1
fi

# Set a flag to track the first time the loop runs
INITIAL_RUN=true

# Begin the structural navigation loop
while true; do
    # 1. Gather all subdirectories inside the Base folder
    CATEGORIES=$(find "$WALLPAPER_BASE" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
    MENU_OPTIONS="[ Base Folder ]\n$CATEGORIES"

    # Stage 1: Select Category Folder
    # Check if this is the first run AND if we have a saved theme state
    if [ "$INITIAL_RUN" = true ] && [ -f "$CURRENT_THEME_FILE" ]; then
        ACTIVE_THEME=$(cat "$CURRENT_THEME_FILE")

        # Verify a wallpaper folder actually matches the theme name
        if echo "$CATEGORIES" | grep -q "^${ACTIVE_THEME}$"; then
            SELECTED_CAT="$ACTIVE_THEME"
        else
            # Fallback to menu if folder is missing
            SELECTED_CAT=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -p "Select Category:")
        fi

        # Turn off the flag so "Go Back" works normally afterwards
        INITIAL_RUN=false
    else
        # Normal behavior for subsequent loops
        SELECTED_CAT=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -p "Select Category:")
    fi

    # If user presses Escape at the folder screen, close Rofi completely
    if [ -z "$SELECTED_CAT" ]; then
        break
    fi

    # Set up our target directory path based on selection
    if [ "$SELECTED_CAT" = "[ Base Folder ]" ]; then
        TARGET_DIR="$WALLPAPER_BASE"
    else
        TARGET_DIR="$WALLPAPER_BASE/$SELECTED_CAT"
    fi

    # 2. Prepend a clean "[ Go Back ]" string block to the front of our image matrix
    rofi_input="[ Go Back ]\n"

    while IFS= read -r file; do
        if [ -n "$file" ]; then
            # Map valid files to their thumbnail paths for the grid engine
            rofi_input+="${file}\0icon\x1f${TARGET_DIR}/${file}\n"
        fi
    done < <(find "$TARGET_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) -printf "%f\n" | sort)

    # If the folder has no images, warn the user and kick them back to Stage 1
    if [ "$rofi_input" = "[ Go Back ]\n" ]; then
        dunstify "No images found inside: $SELECTED_CAT"
        continue
    fi

    # Stage 2: Select Wallpaper (Grid view)
    chosen=$(echo -e "$rofi_input" | rofi -dmenu -theme ~/.config/rofi/grid.rasi -p "Category: $SELECTED_CAT")

    # BACK LOGIC: If user hits Escape OR clicks "[ Go Back ]", drop back to the main categories list
    if [ -z "$chosen" ] || [ "$chosen" = "[ Go Back ]" ]; then
        continue
    fi

    # 3. Apply changes immediately to the desktop background
    feh --bg-scale "$TARGET_DIR/$chosen"

    break
done

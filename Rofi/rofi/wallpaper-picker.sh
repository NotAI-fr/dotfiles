#!/usr/bin/env bash

# Base wallpaper directory
WALLPAPER_BASE="$HOME/Pictures/Walls"

# Integrity Check: Does the base folder exist?
if [ ! -d "$WALLPAPER_BASE" ]; then
    mkdir -p "$WALLPAPER_BASE"
    dunstify "Created ~/Wallpapers folder. Add subfolders here!"
    exit 1
fi

# Begin the structural navigation loop
while true; do
    # 1. Gather all subdirectories inside the Base folder
    CATEGORIES=$(find "$WALLPAPER_BASE" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
    MENU_OPTIONS="[ Base Folder ]\n$CATEGORIES"

    # Stage 1: Select Category Folder (Uses clean text-list theme)
    SELECTED_CAT=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -theme ~/.config/rofi/mono.rasi -p "Select Category:")

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

    # 4. SILENT AUTOMATION: Sync the lockscreen seamlessly with NO BLUR (--fx none)
    # The "&" at the end forks the task to the background so your desktop doesn't stutter
    betterlockscreen -u "$TARGET_DIR/$chosen" --fx none &

    dunstify "Wallpaper & Lockscreen Syncing..." -t 2000
    break
done

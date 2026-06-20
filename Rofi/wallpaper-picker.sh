#!/usr/bin/env bash

WALLPAPER_BASE="$HOME/Pictures/Walls"
CURRENT_THEME_FILE="$HOME/.config/.current_theme"

if [ ! -d "$WALLPAPER_BASE" ]; then
    mkdir -p "$WALLPAPER_BASE"
    dunstify "Created ~/Wallpapers folder. Add subfolders here!"
    exit 1
fi

INITIAL_RUN=true

while true; do
    CATEGORIES=$(find "$WALLPAPER_BASE" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)

    MENU_OPTIONS="<span foreground='#7fbbb3'>󰋜</span>  Base Folder"
    while read -r cat; do
        if [ -z "$cat" ]; then continue; fi
        case "$cat" in
            "monochrome") MENU_OPTIONS+="\n<span foreground='#ffffff'>█</span><span foreground='#444444'>█</span><span foreground='#1a1a1a'>█</span>  Monochrome  monochrome" ;;
            "everforest") MENU_OPTIONS+="\n<span foreground='#a7c080'>█</span><span foreground='#dbbc7f'>█</span><span foreground='#2b3339'>█</span>  Everforest  everforest" ;;
            "gruvbox")    MENU_OPTIONS+="\n<span foreground='#fe8019'>█</span><span foreground='#fabd2f'>█</span><span foreground='#282828'>█</span>  Gruvbox     gruvbox" ;;
            "catppuccin") MENU_OPTIONS+="\n<span foreground='#cba6f7'>█</span><span foreground='#89b4fa'>█</span><span foreground='#585b70'>█</span>  Catppuccin  catppuccin" ;;
            *)
                DISPLAY_NAME=$(echo "$cat" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
                MENU_OPTIONS+="\n<span foreground='#727169'>█</span><span foreground='#555555'>█</span><span foreground='#333333'>█</span>  $DISPLAY_NAME  $cat"
                ;;
        esac
    done <<< "$CATEGORIES"

    if [ "$INITIAL_RUN" = true ] && [ -f "$CURRENT_THEME_FILE" ]; then
        ACTIVE_THEME=$(cat "$CURRENT_THEME_FILE")

        if echo "$CATEGORIES" | grep -q "^${ACTIVE_THEME}$"; then
            SELECTED_CAT="$ACTIVE_THEME"
        else
            SELECTION=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -markup-rows -p "󰏘 Categories" -i -theme-str 'entry { placeholder: "Choose a category 󰏘"; }')
            [ -z "$SELECTION" ] && break

            if [[ "$SELECTION" == *"Base Folder"* ]]; then
                SELECTED_CAT="base"
            else
                SELECTED_CAT=$(echo "$SELECTION" | awk '{print $NF}')
            fi
        fi
        INITIAL_RUN=false
    else
        SELECTION=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -markup-rows -p "󰏘 Categories" -i -theme-str 'entry { placeholder: "Choose a category 󰏘"; }')
        [ -z "$SELECTION" ] && break

        if [[ "$SELECTION" == *"Base Folder"* ]]; then
            SELECTED_CAT="base"
        else
            SELECTED_CAT=$(echo "$SELECTION" | awk '{print $NF}')
        fi
    fi

    if [ "$SELECTED_CAT" = "base" ]; then
        TARGET_DIR="$WALLPAPER_BASE"
        DISPLAY_PROMPT="Base Folder"
    else
        TARGET_DIR="$WALLPAPER_BASE/$SELECTED_CAT"
        DISPLAY_PROMPT=$(echo "$SELECTED_CAT" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
    fi

    rofi_input="[ Go Back ]\n"
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            rofi_input+="${file}\0icon\x1f${TARGET_DIR}/${file}\n"
        fi
    done < <(find "$TARGET_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) -printf "%f\n" | sort)

    if [ "$rofi_input" = "[ Go Back ]\n" ]; then
        dunstify "No images found inside: $DISPLAY_PROMPT"
        continue
    fi

    chosen=$(echo -e "$rofi_input" | rofi -dmenu -theme ~/.config/rofi/grid.rasi -p "󰸉 $DISPLAY_PROMPT")

    if [ -z "$chosen" ] || [ "$chosen" = "[ Go Back ]" ]; then
        continue
    fi

    # =====================================================================
    # 3. Apply changes immediately & Auto-Cache Lock Screen
    # =====================================================================
    feh --bg-scale "$TARGET_DIR/$chosen"

    # Silently fork the betterlockscreen update process to the background
    betterlockscreen -u "$TARGET_DIR/$chosen" > /dev/null 2>&1 &

    break
done

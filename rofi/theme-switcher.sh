#!/usr/bin/env bash

# 1. Base Configuration Directories
THEME_DIR="$HOME/.config/colorschemes"
WALL_BASE_DIR="$HOME/Pictures/Walls"
I3_DIR="$HOME/.config/i3"
POLYBAR_DIR="$HOME/.config/polybar"
KITTY_DIR="$HOME/.config/kitty"
ROFI_DIR="$HOME/.config/rofi"
RMPC_DIR="$HOME/.config/rmpc"
CAVA_DIR="$HOME/.config/cava/themes"
DUNST_DIR="$HOME/.config/dunst"

# 2. Query System Themes via Rofi Menu (With Uniform Color Strips)
OPTIONS=""
OPTIONS+="<span foreground='#ffffff'>█</span><span foreground='#444444'>█</span><span foreground='#1a1a1a'>█</span>  Monochrome     monochrome\n"
OPTIONS+="<span foreground='#a7c080'>█</span><span foreground='#dbbc7f'>█</span><span foreground='#2b3339'>█</span>  Everforest     everforest\n"
OPTIONS+="<span foreground='#fe8019'>█</span><span foreground='#fabd2f'>█</span><span foreground='#282828'>█</span>  Gruvbox        gruvbox\n"
OPTIONS+="<span foreground='#cba6f7'>█</span><span foreground='#89b4fa'>█</span><span foreground='#585b70'>█</span>  Catppuccin     catppuccin\n"
OPTIONS+="<span foreground='#eae4d1'>█</span><span foreground='#b5a2cb'>█</span><span foreground='#4b4652'>█</span>  Lavender Light lavender-light"

SELECTION=$(printf '%b' "$OPTIONS" | rofi -dmenu -markup-rows -p "󰏘 Pick a Theme" -i -theme-str 'entry { placeholder: "Choose a theme 󰏘"; }')

if [[ -z "$SELECTION" ]]; then
    exit 0
fi

THEME=$(awk '{print $NF}' <<< "$SELECTION")
echo "$THEME" > "$HOME/.config/.current_theme"

# 3. Replace active color files with the selected theme assets
cp "$THEME_DIR/$THEME/i3/colors.conf" "$I3_DIR/colors.conf"
cp "$THEME_DIR/$THEME/polybar/colors.ini" "$POLYBAR_DIR/colors.ini"
cp "$THEME_DIR/$THEME/kitty/colors.conf" "$KITTY_DIR/colors.conf"
cp "$THEME_DIR/$THEME/rofi/colors.rasi" "$ROFI_DIR/colors.rasi"
cp "$THEME_DIR/$THEME/rmpc/colors.ron" "$RMPC_DIR/colors.ron"
cp "$THEME_DIR/$THEME/cava/colors" "$CAVA_DIR/colors"
cp "$THEME_DIR/$THEME/dunst/colors.conf" "$DUNST_DIR/dunstrc.d/colors.conf"

# =====================================================================
# 4. Handle Categorized Wallpapers & Auto-Cache Lock Screen
# =====================================================================
# Resolve the default.* wildcard to a specific file so betterlockscreen works.
DEFAULT_WALL=$(find "$WALL_BASE_DIR/$THEME" -maxdepth 1 -type f -name 'default.*' | head -n 1)

if [[ -f "$DEFAULT_WALL" ]]; then
    feh --bg-fill "$DEFAULT_WALL"
    betterlockscreen -u "$DEFAULT_WALL" > /dev/null 2>&1 &
fi

# GTK sync: only change the installed GTK theme and icon theme.
# Every other GTK setting already in settings.ini is left untouched.
GTK_THEME=$(<"$THEME_DIR/$THEME/gtk/theme.txt")
GTK_ICON_THEME=$(<"$THEME_DIR/$THEME/gtk/icon-theme.txt")

set_gtk_setting() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp

    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || printf '[Settings]\n' > "$file"

    if ! grep -q '^\[Settings\][[:space:]]*$' "$file"; then
        printf '\n[Settings]\n' >> "$file"
    fi

    tmp=$(mktemp)
    awk -v key="$key" -v value="$value" '
        BEGIN { in_settings = 0; written = 0 }
        /^\[Settings\][[:space:]]*$/ {
            in_settings = 1
            print
            next
        }
        /^\[/ {
            if (in_settings && !written) {
                print key "=" value
                written = 1
            }
            in_settings = 0
            print
            next
        }
        {
            if (in_settings && $0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
                if (!written) {
                    print key "=" value
                    written = 1
                }
                next
            }
            print
        }
        END {
            if (in_settings && !written) {
                print key "=" value
            }
        }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
}

for GTK_SETTINGS in \
    "$HOME/.config/gtk-3.0/settings.ini" \
    "$HOME/.config/gtk-4.0/settings.ini"
do
    set_gtk_setting "$GTK_SETTINGS" "gtk-theme-name" "$GTK_THEME"
    set_gtk_setting "$GTK_SETTINGS" "gtk-icon-theme-name" "$GTK_ICON_THEME"
done

# 5. Direct Hot-Reload Chain
i3-msg reload

killall xfce4-clipman
xfce4-clipman &

killall dunst
dunst &

killall -q polybar
while pgrep -u "$UID" -x polybar > /dev/null; do
    sleep 0.5
done
polybar main &

killall -SIGUSR1 kitty

notify-send "Theme Switcher" "Theme profile changed to: $THEME"

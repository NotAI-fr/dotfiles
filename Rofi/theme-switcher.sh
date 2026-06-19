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
FETCH_DIR="$HOME/.config/fetch"

# 2. Query System Themes via Rofi Menu (With Uniform Color Strips)
# Using solid blocks (█) wrapped in Pango foreground colors to build color swatches.
# The last word of each line must exactly match your folder name in ~/.config/colorschemes.
OPTIONS=""
OPTIONS+="<span foreground='#ffffff'>█</span><span foreground='#444444'>█</span><span foreground='#1a1a1a'>█</span>  Monochrome  monochrome\n"
OPTIONS+="<span foreground='#a7c080'>█</span><span foreground='#dbbc7f'>█</span><span foreground='#2b3339'>█</span>  Everforest  everforest\n"
OPTIONS+="<span foreground='#fe8019'>█</span><span foreground='#fabd2f'>█</span><span foreground='#282828'>█</span>  Gruvbox     gruvbox\n"
OPTIONS+="<span foreground='#cba6f7'>█</span><span foreground='#89b4fa'>█</span><span foreground='#585b70'>█</span>  Catppuccin  catppuccin"

# Prompt user with the standardized vertical menu.
# We set the entry placeholder property to display the Nerd Font icon and custom text inside the input field.
SELECTION=$(echo -e "$OPTIONS" | rofi -dmenu -markup-rows -p "󰏘 Pick a Theme" -i -theme-str 'entry { placeholder: "Choose a theme 󰏘"; }')

# Graceful exit if escape or cancel is triggered
if [[ -z "$SELECTION" ]]; then
    exit 0
fi

# Extract only the final word of the selection to get the raw folder name
THEME=$(echo "$SELECTION" | awk '{print $NF}')

# SAVE THE THEME STATE FOR THE WALLPAPER PICKER
echo "$THEME" > "$HOME/.config/.current_theme"

# 3. Displace active pointer targets with selected theme assets
cp "$THEME_DIR/$THEME/i3/colors.conf" "$I3_DIR/colors.conf"
cp "$THEME_DIR/$THEME/polybar/colors.ini" "$POLYBAR_DIR/colors.ini"
cp "$THEME_DIR/$THEME/kitty/colors.conf" "$KITTY_DIR/colors.conf"
cp "$THEME_DIR/$THEME/rofi/colors.rasi" "$ROFI_DIR/colors.rasi"
cp "$THEME_DIR/$THEME/rmpc/colors.ron" "$RMPC_DIR/colors.ron"
cp "$THEME_DIR/$THEME/cava/colors" "$CAVA_DIR/colors"
cp "$THEME_DIR/$THEME/dunst/colors.conf" "$DUNST_DIR/dunstrc.d/colors.conf"
cp "$THEME_DIR/$THEME/fetch/config" "$FETCH_DIR/config"

# 4. Handle Categorized Wallpapers via Smart Wildcard Expansion
feh --bg-fill "$WALL_BASE_DIR/$THEME"/default.*

# GTK THEME SYNC
GTK_THEME=$(cat "$THEME_DIR/$THEME/gtk/theme.txt")

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=Papirus-Dark
gtk-font-name = FiraMono Nerd Font 12
gtk-application-prefer-dark-theme=1
EOF

cp "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"


# 5. Direct Hot-Reload Chain
# Refresh i3 keybinds and styles immediately
i3-msg reload

# Gracefully kill the active clipboard instance
killall xfce4-clipman

# Restart it in the background so it reads the new GTK3 configuration
xfce4-clipman &

# restart dunst so new colors are loaded
killall dunst
dunst &

# Cleanly cycle Polybar without dropping tasks
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.5; done
polybar main &

# Send runtime signals directly to all running Kitty terminals
killall -SIGUSR1 kitty

# Success Confirmation
notify-send "Theme Switcher" "Theme profile changed to: $THEME"

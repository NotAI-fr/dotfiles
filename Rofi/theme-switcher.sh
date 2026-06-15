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

# 2. Query System Themes via Rofi Menu
THEME=$(ls -1 "$THEME_DIR" | rofi -dmenu -p "Select Theme" -i)

# Graceful exit if escape or cancel is triggered
if [[ -z "$THEME" ]]; then
    exit 0
fi

# 3. Displace active pointer targets with selected theme assets
cp "$THEME_DIR/$THEME/i3/colors.conf" "$I3_DIR/colors.conf"
cp "$THEME_DIR/$THEME/polybar/colors.ini" "$POLYBAR_DIR/colors.ini"
cp "$THEME_DIR/$THEME/kitty/colors.conf" "$KITTY_DIR/colors.conf"
cp "$THEME_DIR/$THEME/rofi/colors.rasi" "$ROFI_DIR/colors.rasi"
cp "$THEME_DIR/$THEME/rmpc/colors.ron" "$RMPC_DIR/colors.ron"
cp "$THEME_DIR/$THEME/cava/colors" "$CAVA_DIR/colors"
cp "$THEME_DIR/$THEME/dunst/colors.conf" "$DUNST_DIR/dunstrc.d/colors.conf"

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

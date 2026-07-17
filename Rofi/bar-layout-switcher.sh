#!/usr/bin/env bash

# =====================================================================
# POLYBAR LAYOUT SWITCHER
# =====================================================================
# Allows switching between different polybar layout configurations
# Isolated in layouts/ directory for easy extensibility

LAYOUT_DIR="$HOME/.config/polybar/layouts"
LAYOUT_FILE="$HOME/.config/.active_layout"
POLYBAR_CONFIG="$HOME/.config/polybar/config.ini"

# =====================================================================
# 1. Display Layout Selection Menu
# =====================================================================
# =====================================================================
# 1. Display Layout Selection Menu (Dynamic)
# =====================================================================
OPTIONS=""

# Loop through all .ini files in the layouts directory
for file in "$LAYOUT_DIR"/*.ini; do
    # Extract just the filename without the path and without the .ini extension
    layout_name=$(basename "$file" .ini)

    # Add it to the list of options
    OPTIONS+="$layout_name\n"
done

# Show the menu in Rofi
SELECTION=$(echo -e "$OPTIONS" | rofi -dmenu -p "󰦕 Bar Layout" -i -theme-str 'entry { placeholder: "Choose layout 󰦕"; }')

if [[ -z "$SELECTION" ]]; then
    exit 0
fi

# Since there's no descriptive text anymore, the selection IS the layout name
LAYOUT="$SELECTION"
echo "$LAYOUT" > "$LAYOUT_FILE"

# =====================================================================
# 2. Update polybar config to use selected layout
# =====================================================================
# Replace the layout include line in config.ini
sed -i "s|include-file = layouts/.*\.ini|include-file = layouts/$LAYOUT.ini|" "$POLYBAR_CONFIG"

# =====================================================================
# 3. Hot-Reload Polybar
# =====================================================================
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done
polybar main &

notify-send "Polybar Layout" "Changed to: $LAYOUT"

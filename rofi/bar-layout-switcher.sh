#!/usr/bin/env bash

# =====================================================================
# POLYBAR LAYOUT SWITCHER
# =====================================================================
# Allows switching between different polybar layout configurations.
# Also adjusts Picom corner rounding based on the selected layout.

LAYOUT_DIR="$HOME/.config/polybar/layouts"
LAYOUT_FILE="$HOME/.config/.active_layout"
POLYBAR_CONFIG="$HOME/.config/polybar/config.ini"
PICOM_CONFIG="$HOME/.config/picom/picom.conf"

# =====================================================================
# 1. Display Layout Selection Menu
# =====================================================================
OPTIONS=""

# Loop through all .ini files in the layouts directory
for file in "$LAYOUT_DIR"/*.ini; do
    # Skip the loop if no .ini files exist
    [[ -e "$file" ]] || continue

    # Extract just the filename without the path and without the .ini extension
    layout_name=$(basename "$file" .ini)

    # Add it to the list of options
    OPTIONS+="$layout_name\n"
done

# Show the menu in Rofi
SELECTION=$(printf '%b' "$OPTIONS" | rofi -dmenu -p "󰦕 Bar Layout" -i -theme-str 'entry { placeholder: "Choose layout 󰦕"; }')

if [[ -z "$SELECTION" ]]; then
    exit 0
fi

# Since there's no descriptive text anymore, the selection IS the layout name
LAYOUT="$SELECTION"
echo "$LAYOUT" > "$LAYOUT_FILE"

# =====================================================================
# 2. Update Polybar config to use selected layout
# =====================================================================
# Replace the layout include line in config.ini
sed -i "s|include-file = layouts/.*\.ini|include-file = layouts/$LAYOUT.ini|" "$POLYBAR_CONFIG"

# =====================================================================
# 3. Adjust Picom corner radius based on layout
# =====================================================================
case "$LAYOUT" in
    default|minimal)
        # Square corners
        PICOM_CORNER_RADIUS=0
        ;;

    floating-islands)
        # Rounded corners
        PICOM_CORNER_RADIUS=10
        ;;

    *)
        # Leave Picom unchanged for any future/unrecognised layouts
        PICOM_CORNER_RADIUS=""
        ;;
esac

if [[ -n "$PICOM_CORNER_RADIUS" ]]; then
    if [[ ! -f "$PICOM_CONFIG" ]]; then
        notify-send "Polybar Layout" "Changed to: $LAYOUT (Picom config not found)"
        exit 1
    fi

    # Update the existing corner-radius setting.
    # Only the value changes; all other Picom settings remain untouched.
    sed -i "s/^corner-radius = .*/corner-radius = $PICOM_CORNER_RADIUS;/" "$PICOM_CONFIG"
fi

# =====================================================================
# 4. Reload Picom
# =====================================================================
# Only restart Picom when this layout has an explicit corner-radius setting.
if [[ -n "$PICOM_CORNER_RADIUS" ]]; then
    killall -q picom
    while pgrep -u "$UID" -x picom >/dev/null; do sleep 0.1; done
    picom --config "$PICOM_CONFIG" &
fi

# =====================================================================
# 5. Hot-Reload Polybar
# =====================================================================
killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.1; done
polybar main &

notify-send "Polybar Layout" "Changed to: $LAYOUT"

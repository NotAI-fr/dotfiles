#!/usr/bin/env bash
set -u

LOCAL_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/i3/local.env"
[[ -r "$LOCAL_ENV" ]] && source "$LOCAL_ENV"

EXTERNAL_OUTPUT="${EXTERNAL_OUTPUT:-HDMI-2}"
EXTERNAL_MODE="${EXTERNAL_MODE:-1920x1080}"
EXTERNAL_RATE="${EXTERNAL_RATE:-60.00}"
INTERNAL_OUTPUT="${INTERNAL_OUTPUT:-eDP-1}"
DISABLE_INTERNAL="${DISABLE_INTERNAL:-true}"

command -v xrandr >/dev/null 2>&1 || exit 0
xrandr --query | grep -q "^${EXTERNAL_OUTPUT} connected" || exit 0

args=(--output "$EXTERNAL_OUTPUT" --mode "$EXTERNAL_MODE" --rate "$EXTERNAL_RATE" --primary)
if [[ "$DISABLE_INTERNAL" == "true" ]] && xrandr --query | grep -q "^${INTERNAL_OUTPUT} connected"; then
    args+=(--output "$INTERNAL_OUTPUT" --off)
fi

# Fall back to the display's preferred mode if the configured mode/rate is unavailable.
if ! xrandr "${args[@]}"; then
    args=(--output "$EXTERNAL_OUTPUT" --auto --primary)
    if [[ "$DISABLE_INTERNAL" == "true" ]] && xrandr --query | grep -q "^${INTERNAL_OUTPUT} connected"; then
        args+=(--output "$INTERNAL_OUTPUT" --off)
    fi
    xrandr "${args[@]}"
fi

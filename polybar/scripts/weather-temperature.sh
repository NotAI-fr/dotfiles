#!/usr/bin/env bash
set -u

LOCAL_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/polybar/local.env"
[[ -r "$LOCAL_ENV" ]] && source "$LOCAL_ENV"
WEATHER_LOCATION="${WEATHER_LOCATION:-Crewe}"

encoded_location=${WEATHER_LOCATION// /%20}
curl --fail --silent --show-error --max-time 10 \
    "https://wttr.in/${encoded_location}?format=%t" 2>/dev/null || printf -- '--'

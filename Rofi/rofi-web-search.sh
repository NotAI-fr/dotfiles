#!/usr/bin/env bash

# Prompt for the search query via Rofi
QUERY=$(rofi -dmenu -p "󰍉 Google" -theme-str '
  window { width: 500px; border-radius: 12px; padding: 12px; }
  listview { enabled: false; }
')

if [[ -n "$QUERY" ]]; then
    # URL encode spaces by replacing them with plus signs (+) for the Google query string
    ENCODED=$(echo "$QUERY" | tr ' ' '+')
    
    # Launch your default browser straight to Google's search engine
    xdg-open "https://www.google.com/search?q=${ENCODED}" &
fi
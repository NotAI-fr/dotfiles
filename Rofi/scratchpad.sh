#!/usr/bin/env bash

# 1. Setup Directories
NOTE_DIR="$HOME/Notes"
mkdir -p "$NOTE_DIR"

# Individual storage files for clean automatic sorting
FILE_DUMP="$NOTE_DIR/dump.txt"
FILE_TODO="$NOTE_DIR/todo.txt"
FILE_IDEA="$NOTE_DIR/idea.txt"
FILE_NOTE="$NOTE_DIR/general.txt"

# 2. Main Menu: Choose action
MAIN_OPTIONS="󰏫  Capture New Note\n󰈈  View Captured Notes"
CHOICE=$(echo -e "$MAIN_OPTIONS" | rofi -dmenu -i -p "Scratchpad" -theme-str '
  window { width: 350px; border-radius: 12px; padding: 10px; }
  listview { lines: 2; }
')

if [[ -z "$CHOICE" ]]; then
    exit 0
fi

case "$CHOICE" in
    *"Capture New"*)
        # ==========================================
        # MODE A: CAPTURE NOTE
        # ==========================================
        NOTE=$(rofi -dmenu -p "󰏫 Capture" -theme-str '
          window { width: 650px; border-radius: 12px; padding: 12px; }
          listview { enabled: false; }
          entry { placeholder: "Prefix with 󰏔 !dump, 󱓥 !todo, or 󰌵 !idea..."; }
        ')

        if [[ -z "$NOTE" ]]; then exit 0; fi
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

        if [[ "$NOTE" == "!dump "* ]]; then
            CLEAN="${NOTE#\!dump }"
            echo "󰏔 [$TIMESTAMP] $CLEAN" >> "$FILE_DUMP"
            notify-send "Scratchpad" "󰏔 Memory dumped."

        elif [[ "$NOTE" == "!todo "* ]]; then
            CLEAN="${NOTE#\!todo }"
            echo "󱓥 [$TIMESTAMP] $CLEAN" >> "$FILE_TODO"
            notify-send "Scratchpad" "󱓥 Task saved to list."

        elif [[ "$NOTE" == "!idea "* ]]; then
            CLEAN="${NOTE#\!idea }"
            echo "󰌵 [$TIMESTAMP] $CLEAN" >> "$FILE_IDEA"
            notify-send "Scratchpad" "󰌵 Idea recorded."

        else
            # Catch-all general note
            echo "󰎚 [$TIMESTAMP] $NOTE" >> "$FILE_NOTE"
            notify-send "Scratchpad" "󰎚 General note captured."
        fi
        ;;

    *"View Captured"*)
        # ==========================================
        # MODE B: VIEW, SEARCH, COPY, OR DELETE
        # ==========================================
        VIEW_DATA=""

        # Using 'tac' reverses the files so the newest lines appear at the top
        if [[ -s "$FILE_DUMP" ]]; then
            VIEW_DATA+="─────── 󰏔 BRAIN DUMPS ───────\n$(tac "$FILE_DUMP")\n"
        fi
        if [[ -s "$FILE_TODO" ]]; then
            VIEW_DATA+="─────── 󱓥 TO-DO TASKS ───────\n$(tac "$FILE_TODO")\n"
        fi
        if [[ -s "$FILE_IDEA" ]]; then
            VIEW_DATA+="─────── 󰌵 INSIGHTS & IDEAS ───────\n$(tac "$FILE_IDEA")\n"
        fi
        if [[ -s "$FILE_NOTE" ]]; then
            VIEW_DATA+="─────── 󰎚 GENERAL NOTES ───────\n$(cat "$FILE_NOTE" | tac)\n"
        fi

        if [[ -z "$VIEW_DATA" ]]; then
            notify-send "Scratchpad" "No notes recorded yet!"
            exit 0
        fi

        # Launch Rofi with Right-Click mapped to Custom Exit Code 10
        SELECTED_LINE=$(echo -e "$VIEW_DATA" | rofi -dmenu -i -p "󰈈 History" \
          -kb-custom-1 "MouseSecondary" \
          -theme-str '
          window { width: 750px; height: 500px; border-radius: 12px; padding: 12px; }
          entry { placeholder: "󰍉 Left-Click: Copy | Right-Click: Delete Note or Section..."; }
          element { children: [ "element-text" ]; }
          element-text { horizontal-align: 0.5; vertical-align: 0.5; }
        ')

        # Capture how the user exited Rofi (0 = Left Click/Enter, 10 = Right Click)
        ROFI_EXIT=$?

        # Ignore if completely empty selection
        if [[ -z "$SELECTED_LINE" ]]; then
            exit 0
        fi

        # --- SPECIAL HANDLING: SECTION HEADLINES ---
        if [[ "$SELECTED_LINE" == *"───────"* ]]; then
            if [[ $ROFI_EXIT -eq 10 ]]; then
                # Determine which section banner was right-clicked
                if [[ "$SELECTED_LINE" == *"BRAIN DUMPS"* ]]; then
                    TARGET_FILE="$FILE_DUMP"
                    SECTION_NAME="Brain Dumps"
                elif [[ "$SELECTED_LINE" == *"TO-DO TASKS"* ]]; then
                    TARGET_FILE="$FILE_TODO"
                    SECTION_NAME="To-Do Tasks"
                elif [[ "$SELECTED_LINE" == *"INSIGHTS & IDEAS"* ]]; then
                    TARGET_FILE="$FILE_IDEA"
                    SECTION_NAME="Insights & Ideas"
                elif [[ "$SELECTED_LINE" == *"GENERAL NOTES"* ]]; then
                    TARGET_FILE="$FILE_NOTE"
                    SECTION_NAME="General Notes"
                fi

                # Truncate the file entirely
                if [[ -n "$TARGET_FILE" ]]; then
                    > "$TARGET_FILE"
                    notify-send "Scratchpad" "󰆴 Nuked all entries in $SECTION_NAME!"
                fi
            fi
            exit 0
        fi

        # --- NORMAL HANDLING: INDIVIDUAL NOTES ---
        # Extract only the content text for notifications and copying
        JUST_CONTENT="${SELECTED_LINE#*] }"

        # --- ACTION 1: LEFT CLICK / ENTER (COPY CONTENT) ---
        if [[ $ROFI_EXIT -eq 0 ]]; then
            echo -n "$JUST_CONTENT" | xclip -selection clipboard
            notify-send "Scratchpad" "󰆏 Copied: \"$JUST_CONTENT\""

        # --- ACTION 2: RIGHT CLICK (DELETE NOTE) ---
        elif [[ $ROFI_EXIT -eq 10 ]]; then
            # Target the correct storage file by checking the row's leading icon
            if [[ "$SELECTED_LINE" == "󰏔"* ]]; then
                TARGET_FILE="$FILE_DUMP"
            elif [[ "$SELECTED_LINE" == "󱓥"* ]]; then
                TARGET_FILE="$FILE_TODO"
            elif [[ "$SELECTED_LINE" == "󰌵"* ]]; then
                TARGET_FILE="$FILE_IDEA"
            elif [[ "$SELECTED_LINE" == "󰎚"* ]]; then
                TARGET_FILE="$FILE_NOTE"
            fi

            # Safely remove only that specific literal line from the database
            if [[ -n "$TARGET_FILE" ]]; then
                grep -v -F "$SELECTED_LINE" "$TARGET_FILE" > "${TARGET_FILE}.tmp"
                mv "${TARGET_FILE}.tmp" "$TARGET_FILE"
                notify-send "Scratchpad" "󰆴 Deleted: \"$JUST_CONTENT\""
            fi
        fi
        ;;
esac

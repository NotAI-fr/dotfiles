#!/usr/bin/env bash
#
# Sectioned Rofi Config Menu
#
# Opens selected files or folders in Ox inside Kitty.
# Missing entries and empty sections are hidden automatically.
#
# Suggested location:
#   ~/.config/rofi/scripts/config-menu.sh
#

set -uo pipefail

EDITOR_CMD="${CONFIG_EDITOR:-ox}"
TERMINAL_CMD="${CONFIG_TERMINAL:-kitty}"
ROFI_THEME="${CONFIG_MENU_THEME:-}"

declare -a LABELS=()
declare -a PATHS=()

declare -a SECTION_LABELS=()
declare -a SECTION_PATHS=()
SECTION_ICON=""
SECTION_TITLE=""

notify() {
    local title=${1:-"Config Menu"}
    local body=${2:-}

    if command -v dunstify >/dev/null 2>&1; then
        dunstify -a "Config Menu" "$title" "$body"
    fi
}

pretty_name() {
    local value=${1//[-_]/ }

    awk '{
        for (i = 1; i <= NF; i++) {
            $i = toupper(substr($i, 1, 1)) substr($i, 2)
        }
        print
    }' <<< "$value"
}

start_section() {
    SECTION_ICON=$1
    SECTION_TITLE=$2
    SECTION_LABELS=()
    SECTION_PATHS=()
}

section_add_path() {
    local icon=$1
    local name=$2
    local path=$3

    path=${path/#\~/$HOME}

    if [[ -e $path ]]; then
        SECTION_LABELS+=("$icon  $name")
        SECTION_PATHS+=("$path")
    fi
}

section_add_first_existing() {
    local icon=$1
    local name=$2
    shift 2

    local candidate
    for candidate in "$@"; do
        candidate=${candidate/#\~/$HOME}

        if [[ -e $candidate ]]; then
            section_add_path "$icon" "$name" "$candidate"
            return
        fi
    done
}

commit_section() {
    local index

    (( ${#SECTION_LABELS[@]} > 0 )) || return

    # Empty path marks a headline rather than an editable entry.
    LABELS+=("<b>$SECTION_ICON  $SECTION_TITLE</b>")
    PATHS+=("")

    for index in "${!SECTION_LABELS[@]}"; do
        LABELS+=("${SECTION_LABELS[$index]}")
        PATHS+=("${SECTION_PATHS[$index]}")
    done
}

open_in_ox() {
    local path=$1
    local working_dir
    local -a editor=()
    local -a terminal=()
    local -a editor_args=()

    read -r -a editor <<< "$EDITOR_CMD"
    read -r -a terminal <<< "$TERMINAL_CMD"

    if ! command -v "${editor[0]}" >/dev/null 2>&1; then
        notify "Ox not found" "Install Ox or set CONFIG_EDITOR to another terminal editor."
        return 1
    fi

    if ! command -v "${terminal[0]}" >/dev/null 2>&1; then
        notify "Terminal not found" "Install Kitty or set CONFIG_TERMINAL to another compatible terminal."
        return 1
    fi

    if [[ -d $path ]]; then
        # For folders, start Ox in that folder so its file tree uses it as the root.
        working_dir=$path
    else
        # For files, root Ox's file tree in the file's containing folder.
        working_dir=$(dirname -- "$path")
        editor_args+=("$path")
    fi

    nohup "${terminal[@]}" \
        --directory "$working_dir" \
        "${editor[@]}" "${editor_args[@]}" \
        >/dev/null 2>&1 &
}

# ---------------------------------------------------------------------------
# Polybar
# ---------------------------------------------------------------------------

start_section "󰍜" "POLYBAR"

section_add_first_existing "󰐕" "Main" \
    "$HOME/.config/polybar/config.ini" \
    "$HOME/.config/polybar/config"

section_add_path "󰕰" "Modules" \
    "$HOME/.config/polybar/modules.ini"

section_add_path "󰉋" "Layouts Folder" \
    "$HOME/.config/polybar/layouts"

commit_section

# ---------------------------------------------------------------------------
# i3
# ---------------------------------------------------------------------------

start_section "󰍹" "i3"

section_add_path "󰐕" "Main" \
    "$HOME/.config/i3/config"

section_add_first_existing "󰌌" "Keybinds" \
    "$HOME/.config/i3/modules/keybinds.conf" \
    "$HOME/.config/i3/keybinds.conf" \
    "$HOME/.config/i3/keybinds" \
    "$HOME/.config/i3/config.d/keybinds.conf" \
    "$HOME/.config/i3/config.d/keybinds"

section_add_first_existing "󰐥" "Startup" \
    "$HOME/.config/i3/modules/startup.conf" \
    "$HOME/.config/i3/startup.conf" \
    "$HOME/.config/i3/startup" \
    "$HOME/.config/i3/autostart.conf" \
    "$HOME/.config/i3/autostart" \
    "$HOME/.config/i3/config.d/startup.conf" \
    "$HOME/.config/i3/config.d/startup"

commit_section

# ---------------------------------------------------------------------------
# Rofi
# ---------------------------------------------------------------------------

start_section "󰍜" "ROFI"

section_add_path "󰉋" "Folder" \
    "$HOME/.config/rofi"

section_add_path "󰐕" "Main" \
    "$HOME/.config/rofi/config.rasi"

section_add_path "󰹑" "Grid" \
    "$HOME/.config/rofi/grid.rasi"

commit_section

# ---------------------------------------------------------------------------
# RMPC
# ---------------------------------------------------------------------------

start_section "󰎆" "RMPC"

section_add_path "󰐕" "Main" \
    "$HOME/.config/rmpc/config.ron"

section_add_first_existing "󰏘" "Theme" \
    "$HOME/.config/rmpc/theme.ron" \
    "$HOME/.config/rmpc/colors.ron" \
    "$HOME/.config/rmpc/themes/theme.ron" \
    "$HOME/.config/rmpc/themes/default.ron"

commit_section

# ---------------------------------------------------------------------------
# Colorschemes
# One entry is generated for every direct child folder.
# ---------------------------------------------------------------------------

start_section "󰏘" "COLORSCHEMES"

COLORSCHEME_ROOT="$HOME/.config/colorschemes"

if [[ -d $COLORSCHEME_ROOT ]]; then
    while IFS= read -r -d '' scheme_dir; do
        scheme_name=$(basename "$scheme_dir")
        display_name=$(pretty_name "$scheme_name")

        section_add_path "󰉼" "$display_name" "$scheme_dir"
    done < <(
        find "$COLORSCHEME_ROOT" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -print0 2>/dev/null |
        sort -z -f
    )
fi

commit_section

# ---------------------------------------------------------------------------
# Kitty
# ---------------------------------------------------------------------------

start_section "󰄛" "KITTY"

section_add_path "󰐕" "Main" \
    "$HOME/.config/kitty/kitty.conf"

commit_section

# ---------------------------------------------------------------------------

# Count only real entries, not section headlines.
REAL_ENTRY_COUNT=0
for path in "${PATHS[@]}"; do
    [[ -n $path ]] && ((REAL_ENTRY_COUNT += 1))
done

if (( REAL_ENTRY_COUNT == 0 )); then
    notify "No configs found" "None of the configured paths currently exist."
    exit 1
fi

MENU_FILE=$(mktemp "${TMPDIR:-/tmp}/config-menu.XXXXXX")
trap 'rm -f "$MENU_FILE"' EXIT

for index in "${!LABELS[@]}"; do
    if [[ -z ${PATHS[$index]} ]]; then
        # Rofi 2 supports nonselectable rows. The empty-path check below is
        # also retained as a fallback for builds that ignore this metadata.
        printf '%s\0nonselectable\x1ftrue\n' \
            "${LABELS[$index]}" \
            >> "$MENU_FILE"
    else
        # The full path remains searchable without cluttering the visible row.
        printf '%s\0meta\x1f%s\n' \
            "${LABELS[$index]}" \
            "${PATHS[$index]}" \
            >> "$MENU_FILE"
    fi
done

ROFI_ARGS=(
    -dmenu
    -i
    -no-custom
    -markup-rows
    -format i
    -p "󰒓 Configs"
    -mesg "Enter opens the selected file or folder in Ox"
)

if [[ -n $ROFI_THEME && -f $ROFI_THEME ]]; then
    ROFI_ARGS+=(-theme "$ROFI_THEME")
fi

while true; do
    SELECTION=$(rofi "${ROFI_ARGS[@]}" < "$MENU_FILE")
    STATUS=$?

    [[ $STATUS -eq 0 && $SELECTION =~ ^[0-9]+$ ]] || exit 0

    SELECTED_PATH=${PATHS[$SELECTION]}

    # Headlines do nothing if a Rofi build still lets one be selected.
    [[ -n $SELECTED_PATH ]] || continue

    open_in_ox "$SELECTED_PATH"
    exit 0
done

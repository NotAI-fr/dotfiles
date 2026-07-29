#!/usr/bin/env bash
# Theme-aware Rofi wallpaper picker for i3/X11.
#
# Required: rofi, feh
# Optional: imagemagick, betterlockscreen, dunst, xdg-utils
#
# Grid shortcuts:
#   Enter   Apply wallpaper
#   Alt+F   Toggle Favorite
#   Alt+R   Random wallpaper
#   Alt+O   Open current folder

set -uo pipefail

WALLPAPER_BASE="$HOME/Pictures/Walls"
CURRENT_THEME_FILE="$HOME/.config/.current_theme"
COLORSCHEME_ROOT="$HOME/.config/colorschemes"
ROFI_GRID_THEME="$HOME/.config/rofi/grid.rasi"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-picker"
THUMB_DIR="$CACHE_DIR/thumbnails"
LAST_DIR="$CACHE_DIR/last"
CURRENT_FILE="$CACHE_DIR/current.path"
BLS_PENDING="$CACHE_DIR/betterlockscreen.pending"
BLS_LOCK="$CACHE_DIR/betterlockscreen.lock"
FAVORITES_DIR="$WALLPAPER_BASE/Favorites"

THUMB_WIDTH=420
THUMB_HEIGHT=236
THUMB_MAX_AGE_DAYS=45

mkdir -p "$WALLPAPER_BASE" "$FAVORITES_DIR" "$THUMB_DIR" "$LAST_DIR"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-picker.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

ROFI_GRID_ARGS=()
[[ -f "$ROFI_GRID_THEME" ]] && ROFI_GRID_ARGS=(-theme "$ROFI_GRID_THEME")

notify() {
    command -v dunstify >/dev/null 2>&1 &&
        dunstify -a "Wallpaper Picker" "${1:-Wallpaper Picker}" "${2:-}"
}

die() {
    notify "Wallpaper Picker" "$1"
    printf 'wallpaper-picker: %s\n' "$1" >&2
    exit 1
}

command -v rofi >/dev/null 2>&1 || die "rofi is required."
command -v feh >/dev/null 2>&1 || die "feh is required."

# Pick mnemonic bindings, then ask Rofi itself whether each binding is free.
# `-list-keybindings` catches collisions with both Rofi defaults and the
# user's active config before the actual picker is opened.
binding_is_free() {
    local slot=$1
    local candidate=$2

    rofi "-kb-custom-${slot}" "$candidate" -list-keybindings         >/dev/null 2>&1
}

pick_free_binding() {
    local slot=$1
    shift

    local candidate
    for candidate in "$@"; do
        if binding_is_free "$slot" "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

binding_label() {
    sed 's/Control/Ctrl/g' <<< "$1"
}

FAVORITE_KEY=$(pick_free_binding 1     "Control+Alt+f"     "Control+Shift+f"     "Control+Alt+Shift+f") ||
    die "No free mnemonic keybinding was found for Favorites."

RANDOM_KEY=$(pick_free_binding 2     "Control+Alt+r"     "Control+Shift+r"     "Control+Alt+Shift+r") ||
    die "No free mnemonic keybinding was found for Random."

OPEN_KEY=$(pick_free_binding 3     "Control+Alt+o"     "Control+Shift+o"     "Control+Alt+Shift+o") ||
    die "No free mnemonic keybinding was found for Open Folder."

CACHE_KEY=$(pick_free_binding 4     "Control+Alt+c"     "Control+Shift+c"     "Control+Alt+Shift+c") ||
    die "No free mnemonic keybinding was found for Rebuild Cache."

FAVORITE_KEY_LABEL=$(binding_label "$FAVORITE_KEY")
RANDOM_KEY_LABEL=$(binding_label "$RANDOM_KEY")
OPEN_KEY_LABEL=$(binding_label "$OPEN_KEY")
CACHE_KEY_LABEL=$(binding_label "$CACHE_KEY")

pretty_name() {
    local value=${1//[-_]/ }
    awk '{
        for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) substr($i,2)
        print
    }' <<< "$value"
}

safe_name() {
    if [[ $1 =~ ^[A-Za-z0-9._-]+$ ]]; then
        printf '%s\n' "$1"
    else
        printf '%s' "$1" | sha256sum | awk '{print $1}'
    fi
}

resolve_path() {
    readlink -f -- "$1" 2>/dev/null || printf '%s\n' "$1"
}

read_color() {
    local file=$1
    shift
    local key line color

    for key in "$@"; do
        line=$(grep -m1 -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null || true)
        [[ -n $line ]] || continue

        color=$(grep -oE '#[[:xdigit:]]{6}([[:xdigit:]]{2})?' <<< "$line" | head -n1)
        [[ -n $color ]] || continue

        # Polybar commonly stores 8-digit colors as #AARRGGBB.
        [[ ${#color} -eq 9 ]] && color="#${color:3:6}"
        printf '%s\n' "$color"
        return 0
    done

    return 1
}

theme_swatches() {
    local category=$1
    local polybar_dir="$COLORSCHEME_ROOT/$category/polybar"
    local ini=""
    local c1="#727169" c2="#555555" c3="#333333"

    # Each theme normally has:
    #   colors.ini       -> only an include-file line
    #   <theme>.ini      -> the actual [colors] palette
    #
    # Picking the first *.ini is unreliable and often selects colors.ini,
    # causing every swatch to fall back to the same grey values.
    if [[ -f "$polybar_dir/$category.ini" ]]; then
        ini="$polybar_dir/$category.ini"
    elif [[ -d $polybar_dir ]]; then
        while IFS= read -r -d '' candidate; do
            if grep -qE '^[[:space:]]*(bg|fi|fg|alt|border)[[:space:]]*=' \
                    "$candidate" 2>/dev/null; then
                ini=$candidate
                break
            fi
        done < <(
            find "$polybar_dir" -maxdepth 1 -type f -name '*.ini' \
                -print0 2>/dev/null | sort -z
        )
    fi

    if [[ -n $ini ]]; then
        c1=$(read_color "$ini" alt accent primary fg 2>/dev/null || printf '#727169')
        c2=$(read_color "$ini" fg secondary border 2>/dev/null || printf '#555555')
        c3=$(read_color "$ini" fi bg background 2>/dev/null || printf '#333333')
    fi

    printf '%s\t%s\t%s\n' "$c1" "$c2" "$c3"
}

current_wallpaper() {
    local current=""

    if [[ -r "$CURRENT_FILE" ]]; then
        IFS= read -r current < "$CURRENT_FILE" || true
    fi

    if [[ -n $current && -f $current ]]; then
        resolve_path "$current"
        return
    fi

    # Best-effort fallback for a wallpaper set directly by feh.
    if [[ -r "$HOME/.fehbg" ]]; then
        current=$(grep -oE "'[^']+\.(jpg|jpeg|png|webp|bmp)'" "$HOME/.fehbg" 2>/dev/null |
            tail -n1 | sed "s/^'//;s/'$//" || true)
        if [[ -n $current && -f $current ]]; then
            resolve_path "$current"
            return
        fi
    fi

    printf '\n'
}

last_file() {
    printf '%s/%s.path\n' "$LAST_DIR" "$(safe_name "$1")"
}

last_wallpaper() {
    local file value=""
    file=$(last_file "$1")

    [[ -r $file ]] && IFS= read -r value < "$file" || true
    if [[ -n $value && -f $value ]]; then
        resolve_path "$value"
    else
        printf '\n'
    fi
}

remember_last() {
    printf '%s\n' "$2" > "$(last_file "$1")"
}

thumbnail_path() {
    local hash
    hash=$(printf '%s' "$1" | sha256sum | awk '{print $1}')
    printf '%s/%s.png\n' "$THUMB_DIR" "$hash"
}

thumbnail_fresh() {
    [[ -f $2 && ! $1 -nt $2 ]]
}

queue_thumbnail() {
    local source=$1 thumb=$2 lock="${2}.lock"

    thumbnail_fresh "$source" "$thumb" && return

    (
        mkdir "$lock" 2>/dev/null || exit 0
        trap 'rmdir "$lock" 2>/dev/null || true' EXIT

        local tmp="${thumb}.tmp.$$.png"

        if command -v magick >/dev/null 2>&1; then
            nice -n 10 magick "${source}[0]" \
                -auto-orient \
                -thumbnail "${THUMB_WIDTH}x${THUMB_HEIGHT}^" \
                -gravity center \
                -extent "${THUMB_WIDTH}x${THUMB_HEIGHT}" \
                -strip "$tmp" >/dev/null 2>&1
        elif command -v convert >/dev/null 2>&1; then
            nice -n 10 convert "${source}[0]" \
                -auto-orient \
                -thumbnail "${THUMB_WIDTH}x${THUMB_HEIGHT}^" \
                -gravity center \
                -extent "${THUMB_WIDTH}x${THUMB_HEIGHT}" \
                -strip "$tmp" >/dev/null 2>&1
        else
            exit 0
        fi

        if [[ -s $tmp ]]; then
            mv -f -- "$tmp" "$thumb"
            touch -r "$source" "$thumb" 2>/dev/null || true
        else
            rm -f -- "$tmp"
        fi
    ) &
}

rebuild_thumbnails() {
    rm -rf -- "$THUMB_DIR"
    mkdir -p "$THUMB_DIR"
    notify "Thumbnail cache cleared" "It will rebuild quietly while you browse."
}

prune_thumbnails() {
    (
        find "$THUMB_DIR" -maxdepth 1 -type f \
            -mtime "+$THUMB_MAX_AGE_DAYS" -delete 2>/dev/null || true
        find "$THUMB_DIR" -maxdepth 1 -type d -name '*.lock' \
            -mmin +30 -exec rmdir {} + 2>/dev/null || true
    ) &
}

declare -A FAVORITES=()

refresh_favorites() {
    FAVORITES=()
    local link target

    while IFS= read -r -d '' link; do
        target=$(resolve_path "$link")
        [[ -n $target && -f $target ]] && FAVORITES["$target"]=1
    done < <(find "$FAVORITES_DIR" -maxdepth 1 -type l -print0 2>/dev/null)
}

is_favorite() {
    [[ -n ${FAVORITES["$1"]+yes} ]]
}

source_category() {
    local source=$1 relative

    if [[ $source == "$WALLPAPER_BASE/"* ]]; then
        relative=${source#"$WALLPAPER_BASE/"}
        [[ $relative == */* ]] && {
            printf '%s\n' "${relative%%/*}"
            return
        }
    fi

    printf 'base\n'
}

toggle_favorite() {
    local source category base candidate stem ext hash link target

    source=$(resolve_path "$1")
    [[ -f $source ]] || {
        notify "Favorite failed" "That wallpaper no longer exists."
        return
    }

    refresh_favorites

    if is_favorite "$source"; then
        while IFS= read -r -d '' link; do
            target=$(resolve_path "$link")
            [[ $target == "$source" ]] && rm -f -- "$link"
        done < <(find "$FAVORITES_DIR" -maxdepth 1 -type l -print0 2>/dev/null)

        notify "Removed from Favorites" "$(basename "$source")"
        refresh_favorites
        return
    fi

    category=$(source_category "$source")
    base=$(basename "$source")
    candidate="$FAVORITES_DIR/${category}__${base}"

    if [[ -e $candidate || -L $candidate ]]; then
        hash=$(printf '%s' "$source" | sha256sum | cut -c1-8)
        stem=$base
        ext=""
        if [[ $base == *.* ]]; then
            stem=${base%.*}
            ext=".${base##*.}"
        fi
        candidate="$FAVORITES_DIR/${category}__${stem}-${hash}${ext}"
    fi

    ln -s -- "$source" "$candidate"
    notify "Added to Favorites" "$(basename "$source")"
    refresh_favorites
}

update_lockscreen_async() {
    local wallpaper=$1
    command -v betterlockscreen >/dev/null 2>&1 || return

    printf '%s\n' "$wallpaper" > "$BLS_PENDING"

    (
        if command -v flock >/dev/null 2>&1; then
            exec 9>"$BLS_LOCK"
            flock 9
            local pending=""
            while [[ -s $BLS_PENDING ]]; do
                IFS= read -r pending < "$BLS_PENDING" || true
                : > "$BLS_PENDING"
                [[ -n $pending && -f $pending ]] &&
                    betterlockscreen -u "$pending" >/dev/null 2>&1
            done
        else
            betterlockscreen -u "$wallpaper" >/dev/null 2>&1
        fi
    ) &
}

apply_wallpaper() {
    local selected=$1 category=$2 wallpaper current actual_category

    wallpaper=$(resolve_path "$selected")
    [[ -f $wallpaper ]] || {
        notify "Wallpaper missing" "$selected"
        return 1
    }

    current=$(current_wallpaper)
    if [[ -n $current && $wallpaper == "$current" ]]; then
        notify "Already active" "$(basename "$wallpaper")"
        return 0
    fi

    feh --bg-scale "$wallpaper" || {
        notify "Wallpaper failed" "feh could not apply $(basename "$wallpaper")."
        return 1
    }

    printf '%s\n' "$wallpaper" > "$CURRENT_FILE"
    remember_last "$category" "$wallpaper"

    actual_category=$(source_category "$wallpaper")
    [[ $actual_category != "$category" ]] &&
        remember_last "$actual_category" "$wallpaper"

    update_lockscreen_async "$wallpaper"
    notify "Wallpaper changed" "$(basename "$wallpaper")"
}

open_folder() {
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$1" >/dev/null 2>&1 &
    else
        notify "Cannot open folder" "Install xdg-utils for Ctrl+O support."
    fi
}

category_dir() {
    case "$1" in
        base)      printf '%s\n' "$WALLPAPER_BASE" ;;
        favorites) printf '%s\n' "$FAVORITES_DIR" ;;
        *)         printf '%s/%s\n' "$WALLPAPER_BASE" "$1" ;;
    esac
}

list_wallpapers() {
    find -L "$1" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.bmp' \) \
        -print0 2>/dev/null | sort -z -f
}

choose_category() {
    local input="$TMP_DIR/categories.input"
    local -a ids=("base" "favorites") dirs=()
    local category display c1 c2 c3 index status

    {
        printf "<span foreground='#7fbbb3'>󰋜</span>  Base Folder\n"
        printf "<span foreground='#e6c384'>󰋪</span>  Favorites\n"
    } > "$input"

    mapfile -d '' dirs < <(
        find "$WALLPAPER_BASE" -mindepth 1 -maxdepth 1 -type d \
            ! -iname 'Favorites' -printf '%f\0' 2>/dev/null | sort -z -f
    )

    for category in "${dirs[@]}"; do
        ids+=("$category")
        display=$(pretty_name "$category")
        IFS=$'\t' read -r c1 c2 c3 < <(theme_swatches "$category")
        printf "<span foreground='%s'>█</span><span foreground='%s'>█</span><span foreground='%s'>█</span>  %s\n" \
            "$c1" "$c2" "$c3" "$display" >> "$input"
    done

    index=$(rofi -dmenu -markup-rows -i -format i \
        -p "󰏘 Categories" \
        -theme-str 'entry { placeholder: "Choose a category 󰏘"; }' \
        < "$input")
    status=$?

    [[ $status -eq 0 && $index =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "${ids[$index]}"
}

random_wallpaper() {
    local category=$1
    shift
    local -a files=("$@")
    local count=${#files[@]} current chosen attempts=0

    (( count > 0 )) || {
        notify "No wallpapers" "This category is empty."
        return 1
    }

    current=$(current_wallpaper)
    chosen=${files[RANDOM % count]}

    while (( count > 1 && attempts < 8 )) &&
          [[ $(resolve_path "$chosen") == "$current" ]]; do
        chosen=${files[RANDOM % count]}
        ((attempts++))
    done

    apply_wallpaper "$chosen" "$category"
}

browse_category() {
    local category=$1 directory prompt input="$TMP_DIR/wallpapers.input"
    local current last selected_row index status selected
    local source resolved filename markers label thumb icon src_theme
    local -a files=() entries=()
    local special_count=1

    directory=$(category_dir "$category")
    prompt=$(pretty_name "$category")

    [[ -d $directory ]] || {
        notify "Folder missing" "$directory"
        return 2
    }

    while true; do
        mapfile -d '' files < <(list_wallpapers "$directory")
        (( ${#files[@]} > 0 )) || {
            notify "No images found" "$prompt"
            return 2
        }

        refresh_favorites
        current=$(current_wallpaper)
        last=$(last_wallpaper "$category")
        selected_row=0
        entries=()
        : > "$input"

        entries+=("__back__")
        printf '󰁍  [ Go Back ]\n' >> "$input"

        for source in "${files[@]}"; do
            resolved=$(resolve_path "$source")
            [[ -f $resolved ]] || continue

            filename=$(basename "$resolved")
            markers=""

            if [[ $resolved == "$current" ]]; then
                markers+="󰄬 "
                selected_row=${#entries[@]}
            fi
            is_favorite "$resolved" && markers+="󰋪 "
            if [[ -n $last && $resolved == "$last" && $resolved != "$current" ]]; then
                markers+="󰁯 "
                (( selected_row == 0 )) && selected_row=${#entries[@]}
            fi

            if [[ $category == favorites ]]; then
                src_theme=$(pretty_name "$(source_category "$resolved")")
                label="${markers}[${src_theme}] ${filename}"
            else
                label="${markers}${filename}"
            fi

            thumb=$(thumbnail_path "$resolved")
            if thumbnail_fresh "$resolved" "$thumb"; then
                icon=$thumb
            else
                icon=$resolved
                queue_thumbnail "$resolved" "$thumb"
            fi

            entries+=("$source")
            printf '%s\0icon\x1f%s\n' "$label" "$icon" >> "$input"
        done

        index=$(rofi -dmenu -i -format i \
            -selected-row "$selected_row" \
            -kb-custom-1 "$FAVORITE_KEY" \
            -kb-custom-2 "$RANDOM_KEY" \
            -kb-custom-3 "$OPEN_KEY" \
            -kb-custom-4 "$CACHE_KEY" \
            -mesg "Enter: apply   $FAVORITE_KEY_LABEL: favorite   $RANDOM_KEY_LABEL: random   $OPEN_KEY_LABEL: folder   $CACHE_KEY_LABEL: cache" \
            "${ROFI_GRID_ARGS[@]}" \
            -p "󰸉 $prompt" < "$input")
        status=$?

        case "$status" in
            0)
                [[ $index =~ ^[0-9]+$ ]] || continue
                selected=${entries[$index]}
                case "$selected" in
                    __back__) return 2 ;;
                    *)        apply_wallpaper "$selected" "$category"; return $? ;;
                esac
                ;;
            1)
                return 2
                ;;
            10)
                if [[ $index =~ ^[0-9]+$ ]] && (( index >= special_count )); then
                    toggle_favorite "${entries[$index]}"
                else
                    notify "Choose a wallpaper" "Highlight a wallpaper before using $FAVORITE_KEY_LABEL."
                fi
                ;;
            11)
                random_wallpaper "$category" "${files[@]}"
                return $?
                ;;
            12)
                open_folder "$directory"
                ;;
            13)
                rebuild_thumbnails
                ;;
            *)
                return 2
                ;;
        esac
    done
}

prune_thumbnails

initial_run=true
while true; do
    selected_category=""

    if [[ $initial_run == true && -r $CURRENT_THEME_FILE ]]; then
        IFS= read -r active_theme < "$CURRENT_THEME_FILE" || true
        if [[ -n ${active_theme:-} && -d "$WALLPAPER_BASE/$active_theme" ]]; then
            selected_category=$active_theme
        fi
    fi
    initial_run=false

    [[ -n $selected_category ]] ||
        selected_category=$(choose_category) ||
        break

    browse_category "$selected_category"
    [[ $? -eq 0 ]] && break
done

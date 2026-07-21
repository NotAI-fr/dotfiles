#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
INSTALL_PACKAGES=false
DRY_RUN=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --packages   Install official and optional AUR dependencies first.
  --dry-run    Print deployment actions without changing files.
  -h, --help   Show this help.

Without --packages, the script only deploys configuration files.
EOF
}

while (($#)); do
    case "$1" in
        --packages) INSTALL_PACKAGES=true ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

run() {
    if $DRY_RUN; then
        printf '+ '
        printf '%q ' "$@"
        printf '\n'
    else
        "$@"
    fi
}

install_packages() {
    mapfile -t official < <(grep -vE '^[[:space:]]*(#|$)' "$DOTFILES_DIR/packages.txt")
    run sudo pacman -S --needed "${official[@]}"

    if ! command -v paru >/dev/null 2>&1; then
        echo "paru is required for optional AUR packages."
        echo "Install it manually, then rerun ./install.sh --packages."
        return 0
    fi

    while IFS= read -r package; do
        [[ -n "$package" && "$package" != \#* ]] || continue
        if ! $DRY_RUN && ! paru -S --needed "$package"; then
            echo "Warning: optional AUR package failed: $package"
        elif $DRY_RUN; then
            echo "+ paru -S --needed $package"
        fi
    done < "$DOTFILES_DIR/packages-aur.txt"
}

backup_path() {
    local target=$1 relative=$2
    [[ -e "$target" || -L "$target" ]] || return 0
    run mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
    run mv "$target" "$BACKUP_DIR/$relative"
}

deploy_dir() {
    local name=$1 source="$DOTFILES_DIR/$1" target="$CONFIG_DIR/$1"
    [[ -d "$source" ]] || { echo "Skipping missing directory: $source"; return; }
    backup_path "$target" "$name"
    run mkdir -p "$CONFIG_DIR"
    run cp -a "$source" "$target"
}

deploy_file() {
    local source=$1 target=$2 relative=$3
    [[ -f "$source" ]] || return 0
    backup_path "$target" "$relative"
    run mkdir -p "$(dirname "$target")"
    run cp -a "$source" "$target"
}

$INSTALL_PACKAGES && install_packages

for component in i3 polybar kitty rofi dunst colorschemes rmpc mpd mpv picom fastfetch; do
    deploy_dir "$component"
done

WALL_TARGET="$HOME/Pictures/Walls"
backup_path "$WALL_TARGET" "Pictures/Walls"
run mkdir -p "$HOME/Pictures"
run cp -a "$DOTFILES_DIR/Walls" "$WALL_TARGET"

deploy_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
deploy_file "$DOTFILES_DIR/starship.toml" "$CONFIG_DIR/starship.toml" "starship.toml"

# Create editable machine-local files only when they do not already exist.
if [[ ! -e "$CONFIG_DIR/i3/local.env" ]]; then
    run cp "$CONFIG_DIR/i3/local.env.example" "$CONFIG_DIR/i3/local.env"
fi
if [[ ! -e "$CONFIG_DIR/polybar/local.env" ]]; then
    run cp "$CONFIG_DIR/polybar/local.env.example" "$CONFIG_DIR/polybar/local.env"
fi

if ! $DRY_RUN; then
    find "$CONFIG_DIR/i3" "$CONFIG_DIR/polybar" "$CONFIG_DIR/rofi" \
        -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} +
fi

echo
echo "Deployment complete."
echo "Backups: $BACKUP_DIR"
echo "Review before starting i3:"
echo "  $CONFIG_DIR/i3/local.env"
echo "  $CONFIG_DIR/i3/modules/00-apps.conf"
echo "  $CONFIG_DIR/polybar/local.env"

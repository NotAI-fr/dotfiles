#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/dotfiles"

sync_dir() {
    local source="$1"
    local destination="$2"
    shift 2

    if [[ ! -d "$source" ]]; then
        echo "Skipping missing directory: $source"
        return
    fi

    mkdir -p "$destination"
    rsync -av --delete "$@" "$source/" "$destination/"
}

sync_file() {
    local source="$1"
    local destination="$2"

    if [[ ! -f "$source" ]]; then
        echo "Skipping missing file: $source"
        return
    fi

    cp -av "$source" "$destination"
}

cd "$REPO_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "The dotfiles repo has uncommitted changes."
    echo "Commit or discard them before running the backup."
    exit 1
fi

echo "Updating the repo from GitHub..."
git pull --ff-only origin main

echo "Copying live configs into the repo..."

sync_dir "$HOME/Pictures/Walls" "$REPO_DIR/Walls"
sync_dir "$HOME/.config/rofi" "$REPO_DIR/rofi"
sync_dir "$HOME/.config/fastfetch" "$REPO_DIR/fastfetch"
sync_dir "$HOME/.config/kitty" "$REPO_DIR/kitty"
sync_dir "$HOME/.config/rmpc" "$REPO_DIR/rmpc"

sync_dir "$HOME/.config/i3" "$REPO_DIR/i3" \
    --exclude='local.env.example' \
    --exclude='modules/00-apps.conf' \
    --exclude='scripts/setup-monitor.sh'

sync_dir "$HOME/.config/polybar" "$REPO_DIR/polybar" \
    --exclude='local.env.example' \
    --exclude='scripts/weather-temperature.sh' \
    --exclude='scripts/psn/README.md' \
    --exclude='scripts/psn/npsso.example' \
    --exclude='scripts/psn/npsso' \
    --exclude='scripts/psn/auth_tokens.json' \
    --exclude='scripts/psn/cache/' \
    --exclude='scripts/psn/venv/' \
    --exclude='scripts/psn/*.bak-*'

sync_dir "$HOME/.config/mpv" "$REPO_DIR/mpv"

sync_dir "$HOME/.config/mpd" "$REPO_DIR/mpd" \
    --exclude='database' \
    --exclude='log' \
    --exclude='pid' \
    --exclude='state' \
    --exclude='sticker.sql'

sync_dir "$HOME/.config/picom" "$REPO_DIR/picom"
sync_dir "$HOME/.config/colorschemes" "$REPO_DIR/colorschemes"
sync_dir "$HOME/.config/dunst" "$REPO_DIR/dunst"

sync_file "$HOME/.oxrc" "$REPO_DIR/.oxrc"
sync_dir "$HOME/.config/ox" "$REPO_DIR/ox"

sync_file "$HOME/.zshrc" "$REPO_DIR/.zshrc"
sync_file "$HOME/.config/starship.toml" "$REPO_DIR/starship.toml"

git add -A

if git diff --cached --quiet; then
    echo "No config changes to commit."
else
    git commit -m "Automated backup: $(date +'%Y-%m-%d %H:%M')"
fi

git push origin main

echo "Backup complete."

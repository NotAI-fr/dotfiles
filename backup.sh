#!/usr/bin/env bash
set -euo pipefail

# The repository is always the folder containing this script.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Syncing active i3/X11 configs into: $REPO_DIR"

sync_dir() {
    local source=$1
    local destination=$2

    if [[ ! -d "$source" ]]; then
        echo "Skipping missing directory: $source"
        return
    fi

    mkdir -p "$destination"

    rsync -a --delete \
        --exclude 'npsso' \
        --exclude 'cache/' \
        --exclude 'venv/' \
        --exclude 'database' \
        --exclude 'log' \
        --exclude 'pid' \
        --exclude 'state' \
        --exclude 'sticker.sql' \
        "$source/" "$destination/"
}

sync_file() {
    local source=$1
    local destination=$2

    if [[ ! -f "$source" ]]; then
        echo "Skipping missing file: $source"
        return
    fi

    cp -a "$source" "$destination"
}

# Desktop and application configs
sync_dir "$HOME/Pictures/Walls"       "$REPO_DIR/Walls"
sync_dir "$HOME/.config/rofi"         "$REPO_DIR/rofi"
sync_dir "$HOME/.config/fastfetch"    "$REPO_DIR/fastfetch"
sync_dir "$HOME/.config/kitty"        "$REPO_DIR/kitty"
sync_dir "$HOME/.config/rmpc"         "$REPO_DIR/rmpc"
sync_dir "$HOME/.config/i3"           "$REPO_DIR/i3"
sync_dir "$HOME/.config/polybar"      "$REPO_DIR/polybar"
sync_dir "$HOME/.config/mpv"          "$REPO_DIR/mpv"
sync_dir "$HOME/.config/mpd"          "$REPO_DIR/mpd"
sync_dir "$HOME/.config/picom"        "$REPO_DIR/picom"
sync_dir "$HOME/.config/colorschemes" "$REPO_DIR/colorschemes"
sync_dir "$HOME/.config/dunst"        "$REPO_DIR/dunst"

# Ox editor
sync_file "$HOME/.oxrc"               "$REPO_DIR/.oxrc"
sync_dir  "$HOME/.config/ox"          "$REPO_DIR/ox"

# Shell and prompt
sync_file "$HOME/.zshrc"              "$REPO_DIR/.zshrc"
sync_file "$HOME/.config/starship.toml" "$REPO_DIR/starship.toml"

cd "$REPO_DIR"
git add -A

if git diff --cached --quiet; then
    echo "No configuration changes to commit."
else
    git commit -m "Automated i3 backup: $(date +'%Y-%m-%d %H:%M')"
fi

git pull --rebase origin main
git push origin main

echo "Backup complete. Archived Wayland folders were left untouched."

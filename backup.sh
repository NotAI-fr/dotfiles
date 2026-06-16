#!/bin/bash

REPO_DIR="$HOME/dotfiles"

echo "Syncing configs to repo using rsync..."

# Note: The trailing slash on source (e.g., hypr/) is important for rsync
rsync -av --delete "$HOME/.config/hypr/" "$REPO_DIR/hypr/"
rsync -av --delete "$HOME/Pictures/Walls/" "$REPO_DIR/Walls/"
rsync -av --delete "$HOME/.config/rofi/" "$REPO_DIR/Rofi/"
rsync -av --delete "$HOME/.p10k.zsh" "$REPO_DIR/"
rsync -av --delete "$HOME/.config/fastfetch/" "$REPO_DIR/fastfetch/"
rsync -av --delete "$HOME/.config/kitty/" "$REPO_DIR/kitty/"
rsync -av --delete "$HOME/.config/rmpc/" "$REPO_DIR/rmpc/"
rsync -av --delete "$HOME/.config/wayle/" "$REPO_DIR/wayle/"
rsync -av --delete "$HOME/.config/wlogout/" "$REPO_DIR/wlogout/"
rsync -av --delete "$HOME/.config/i3/" "$REPO_DIR/i3/"
rsync -av --delete "$HOME/.config/polybar/" "$REPO_DIR/polybar/"
rsync -av --delete "$HOME/.config/mpv/" "$REPO_DIR/mpv/"
rsync -av --delete "$HOME/.config/mpd/" "$REPO_DIR/mpd/"
rsync -av --delete "$HOME/.zshrc" "$REPO_DIR/"
rsync -av --delete "$HOME/.config/starship.toml" "$REPO_DIR/"
rsync -av --delete "$HOME/.config/picom/" "$REPO_DIR/picom/"
rsync -av --delete "$HOME/.config/colorschemes/" "$REPO_DIR/colorschemes/"
rsync -av --delete "$HOME/.config/dunst/" "$REPO_DIR/dunst/"
rsync -av --delete "$HOME/.config/assets/" "$REPO_DIR/assets/"

echo "Syncing with GitHub..."
cd "$REPO_DIR" || exit

# 1. Fetch remote changes first so local Git is aware of the remote README
git fetch origin main

# 2. Add local changes and commit them if there are any
git add .
if [[ -n $(git status -s) ]]; then
    git commit -m "Automated backup: $(date +'%Y-%m-%d %H:%M')"
fi

# 3. Pull remote changes and automatically accept the merge message without an editor
# This brings down your web-edited README and merges it with your local config changes seamlessly.
git pull --no-rebase --no-edit origin main

# 4. Push everything back up safely
git push origin main

echo "Backup complete."

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

echo "Syncing with GitHub..."
cd "$REPO_DIR" || exit

# 2. Add and Commit
git add .
if [[ -n $(git status -s) ]]; then
    git commit -m "Automated backup: $(date +'%Y-%m-%d %H:%M')"
fi

# 3. Pull (with merge) to resolve divergence, then push
git pull --no-rebase origin main
git push origin main

echo "Backup complete."

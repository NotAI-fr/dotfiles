#!/bin/bash

REPO_DIR="$HOME/dotfiles"

echo "Syncing configs to repo using rsync..."

# Note: The trailing slash on source (e.g., hypr/) is important for rsync
rsync -rtv --delete "$HOME/.config/hypr/" "$REPO_DIR/hypr/"
rsync -rtv --delete "$HOME/Pictures/Walls/" "$REPO_DIR/Walls/"
rsync -rtv --delete "$HOME/.config/rofi/" "$REPO_DIR/Rofi/"
rsync -rtv --delete "$HOME/.p10k.zsh" "$REPO_DIR/"
rsync -rtv --delete "$HOME/.config/fastfetch/" "$REPO_DIR/fastfetch/"
rsync -rtv --delete "$HOME/.config/kitty/" "$REPO_DIR/kitty/"
rsync -rtv --delete "$HOME/.config/rmpc/" "$REPO_DIR/rmpc/"
rsync -rtv --delete "$HOME/.config/wayle/" "$REPO_DIR/wayle/"
rsync -rtv --delete "$HOME/.config/wlogout/" "$REPO_DIR/wlogout/"
rsync -rtv --delete "$HOME/.config/i3/" "$REPO_DIR/i3/"
rsync -rtv --delete "$HOME/.config/polybar/" "$REPO_DIR/polybar/"
rsync -rtv --delete "$HOME/.config/mpv/" "$REPO_DIR/mpv/"
rsync -rtv --delete "$HOME/.config/mpd/" "$REPO_DIR/mpd/"
rsync -rtv --delete "$HOME/.zshrc" "$REPO_DIR/"
rsync -rtv --delete "$HOME/.config/starship.toml" "$REPO_DIR/"
rsync -rtv --delete "$HOME/.config/picom/" "$REPO_DIR/picom/"

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

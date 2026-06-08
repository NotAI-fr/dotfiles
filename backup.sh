#!/bin/bash

# 1. Define where your Git repo lives
REPO_DIR="$HOME/dotfiles"

echo "Copying your current configs into the repo..."

# 2. Copy your files.
# (The trailing slash means it copies the *contents* of the hypr folder)
cp -r "$HOME/.config/hypr/" "$REPO_DIR/hypr/"
cp -r "$HOME/Pictures/Walls/" "$REPO_DIR/Walls/"
cp -r "$HOME/.config/rofi/" "$REPO_DIR/Rofi/"
cp -r "$HOME/.p10k.zsh" "$REPO_DIR/"
cp -r "$HOME/.config/fastfetch/" "$REPO_DIR/fastfetch/"
cp -r "$HOME/.config/kitty/" "$REPO_DIR/kitty/"
cp -r "$HOME/.config/rmpc/" "$REPO_DIR/rmpc/"
cp -r "$HOME/.config/wayle/" "$REPO_DIR/wayle/"
cp -r "$HOME/.config/wlogout/" "$REPO_DIR/wlogout/"
cp -r "$HOME/.config/i3/" "$REPO_DIR/i3/"
cp -r "$HOME/.config/polybar/" "$REPO_DIR/polybar/"

# You can add as many of these as you want later!
# cp -r "$HOME/.config/kitty/" "$REPO_DIR/kitty/"

echo "Files copied! Now talking to Git..."

# 3. Move into the repo folder so Git commands work
cd "$REPO_DIR" || exit

# 4. The Automated Git Pipeline
git add .
git commit -m "Automated backup on $(date +'%Y-%m-%d %H:%M')"
git push

echo "Success! Your dots are safely backed up to GitHub."

#!/bin/bash

REPO_DIR="$HOME/dotfiles"

echo "Syncing configs to repo using rsync..."

# This keeps the original backup script's rsync/fetch/commit/merge/push flow.
# Only these functional updates were made:
#   1. Rofi is stored under lowercase rofi/
#   2. Ox backs up ~/.oxrc and ~/.config/ox/
#   3. Known repo-only helper/example files are protected from --delete
#   4. Private/generated PSN files are excluded from the repo copy

# Note: The trailing slash on directory sources is important for rsync.
rsync -av --delete "$HOME/.config/hypr/" "$REPO_DIR/hypr/"
rsync -av --delete "$HOME/Pictures/Walls/" "$REPO_DIR/Walls/"

# Lowercase Rofi repository directory.
rsync -av --delete "$HOME/.config/rofi/" "$REPO_DIR/rofi/"

rsync -av --delete "$HOME/.p10k.zsh" "$REPO_DIR/"
rsync -av --delete "$HOME/.config/fastfetch/" "$REPO_DIR/fastfetch/"
rsync -av --delete "$HOME/.config/kitty/" "$REPO_DIR/kitty/"
rsync -av --delete "$HOME/.config/rmpc/" "$REPO_DIR/rmpc/"
rsync -av --delete "$HOME/.config/wayle/" "$REPO_DIR/wayle/"
rsync -av --delete "$HOME/.config/wlogout/" "$REPO_DIR/wlogout/"

# Keep repo-only example/helper files that do not live under ~/.config/i3.
rsync -av --delete \
    --exclude 'local.env.example' \
    --exclude 'modules/00-apps.conf' \
    --exclude 'scripts/setup-monitor.sh' \
    "$HOME/.config/i3/" "$REPO_DIR/i3/"

# Keep repo-only documentation/examples and do not copy PSN secrets/runtime data.
rsync -av --delete \
    --exclude 'local.env.example' \
    --exclude 'scripts/psn/README.md' \
    --exclude 'scripts/psn/npsso.example' \
    --exclude 'scripts/psn/npsso' \
    --exclude 'scripts/psn/cache/' \
    --exclude 'scripts/psn/venv/' \
    --exclude 'scripts/weather-temperature.sh' \
    "$HOME/.config/polybar/" "$REPO_DIR/polybar/"

rsync -av --delete "$HOME/.config/mpv/" "$REPO_DIR/mpv/"
rsync -av --delete "$HOME/.config/mpd/" "$REPO_DIR/mpd/"
rsync -av --delete "$HOME/.zshrc" "$REPO_DIR/"
rsync -av --delete "$HOME/.config/starship.toml" "$REPO_DIR/"
rsync -av --delete "$HOME/.config/picom/" "$REPO_DIR/picom/"
rsync -av --delete "$HOME/.config/colorschemes/" "$REPO_DIR/colorschemes/"
rsync -av --delete "$HOME/.config/dunst/" "$REPO_DIR/dunst/"
rsync -av --delete "$HOME/.config/assets/" "$REPO_DIR/assets/"
rsync -av --delete "$HOME/.config/install.sh" "$REPO_DIR/"
rsync -av --delete "$HOME/.config/packages.txt" "$REPO_DIR/"

# Ox editor configuration.
rsync -av --delete "$HOME/.oxrc" "$REPO_DIR/"
rsync -av --delete "$HOME/.config/ox/" "$REPO_DIR/ox/"

echo "Syncing with GitHub..."
cd "$REPO_DIR" || exit

# 1. Fetch remote changes first so local Git is aware of remote README edits.
git fetch origin main

# 2. Add local changes and commit them if there are any.
git add .
if [[ -n $(git status -s) ]]; then
    git commit -m "Automated backup: $(date +'%Y-%m-%d %H:%M')"
fi

# 3. Use the original merge-based pull, not a rebase.
git pull --no-rebase --no-edit origin main

# 4. Push everything back up.
git push origin main

echo "Backup complete."

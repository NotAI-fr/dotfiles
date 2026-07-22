#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/dotfiles"

cd "$REPO_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "The dotfiles repo has uncommitted changes."
    echo "Commit or discard them before syncing from GitHub."
    exit 1
fi

echo "Downloading the latest repo changes from GitHub..."
git pull --ff-only origin main

echo "The local dotfiles repo is up to date."
echo "This script does not copy anything into ~/.config."

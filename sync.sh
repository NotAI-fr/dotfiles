#!/bin/bash

# Define where your repo lives
REPO_DIR="$HOME/dotfiles"

echo "Syncing your local dotfiles with GitHub..."

# 1. Move into the directory
cd "$REPO_DIR" || exit

# 2. Check if the directory is clean (no uncommitted changes)
if [[ -n $(git status -s) ]]; then
    echo "Warning: You have uncommitted changes in $REPO_DIR."
    echo "Please commit or stash your changes before pulling."
    exit 1
fi

# 3. Pull the latest from the cloud
git pull

echo "Local folder is now up-to-date with GitHub."

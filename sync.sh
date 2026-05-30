#!/bin/bash

# Define where your repo lives
REPO_DIR="$HOME/dotfiles"

echo "Syncing your local dotfiles with GitHub..."

# 1. Move into the directory
cd "$REPO_DIR" || exit

# 2. Pull the latest from the cloud
git pull

echo "Local folder is now up to date with GitHub."

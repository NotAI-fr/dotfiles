#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Define base paths
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
PKG_FILE="$DOTFILES_DIR/packages.txt"

echo "🚀 Starting clean dotfiles deployment..."

# 1. Integrity Check for the Package List
if [ ! -f "$PKG_FILE" ]; then
    echo "❌ Error: $PKG_FILE not found! Make sure it's in the same folder as this script."
    exit 1
fi

# Read packages into an array, ignoring empty lines and comments
mapfile -t PACKAGES < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE")

# 2. Automatically Bootstrap paru if it's missing
if ! command -v paru &> /dev/null; then
    echo "📦 paru not found! Bootstrapping paru automatically..."

    # Install required build tools first
    sudo pacman -S --needed --noconfirm base-devel git

    # Clone and build paru-bin (faster to install than compiling from source)
    BUILD_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$BUILD_DIR"

    # Change to directory, build, and install
    cd "$BUILD_DIR"
    makepkg -si --noconfirm

    # Clean up and return to dotfiles directory
    cd "$DOTFILES_DIR"
    rm -rf "$BUILD_DIR"
    echo "✅ paru installed successfully!"
fi

# 3. Install All Packages from packages.txt
echo "📥 Installing listed packages via paru..."
paru -S --needed --noconfirm "${PACKAGES[@]}"

# Ensure base configuration directory exists
mkdir -p "$CONFIG_DIR"

# 4. List of configuration folders to copy directly
CONFIGS=(i3 polybar kitty rofi dunst colorschemes rmpc cava fetch)

echo "📂 Copying configuration files..."
for config in "${CONFIGS[@]}"; do
    TARGET="$CONFIG_DIR/$config"
    SOURCE="$DOTFILES_DIR/config/$config"

    if [ -d "$SOURCE" ]; then
        # Safety Backup: Move old folder out of the way instead of overwriting
        if [ -d "$TARGET" ]; then
            echo "🗄️ Existing config found for '$config'. Moving to backup..."
            mkdir -p "$BACKUP_DIR"
            mv "$TARGET" "$BACKUP_DIR/$config"
        fi

        echo "📥 Copying: $config -> $TARGET"
        cp -r "$SOURCE" "$TARGET"
    else
        echo "⚠️ Warning: '$SOURCE' not found in your repository. Skipping."
    fi
done

# 5. Handle Wallpapers Directory
WALL_TARGET="$HOME/Pictures/Walls"
WALL_SOURCE="$DOTFILES_DIR/Pictures/Walls"

if [ -d "$WALL_SOURCE" ]; then
    if [ -d "$WALL_TARGET" ]; then
        echo "🗄️ Existing Walls folder found. Moving to backup..."
        mkdir -p "$BACKUP_DIR"
        mv "$WALL_TARGET" "$BACKUP_DIR/Walls"
    fi

    echo "🖼️ Copying Wallpapers -> $WALL_TARGET"
    mkdir -p "$(dirname "$WALL_TARGET")"
    cp -r "$WALL_SOURCE" "$WALL_TARGET"
fi

echo "🎉 Done! Everything has been copied over cleanly without symlinks."
echo "ℹ️ Backups of any old configs are safe at: $BACKUP_DIR"

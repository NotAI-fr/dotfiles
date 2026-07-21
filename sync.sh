#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

if [[ -n $(git status --short) ]]; then
    echo "Refusing to pull: the repository has uncommitted changes."
    echo "Commit, stash, or discard them first."
    exit 1
fi

git pull --ff-only origin main

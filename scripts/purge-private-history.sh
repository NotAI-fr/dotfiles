#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Run this inside the dotfiles Git repository."
    exit 1
}
cd "$ROOT"

command -v git-filter-repo >/dev/null 2>&1 || {
    echo "Install git-filter-repo first: sudo pacman -S git-filter-repo"
    exit 1
}

[[ -z $(git status --short) ]] || {
    echo "Commit or stash all changes before rewriting history."
    exit 1
}

printf '%s\n' "This permanently rewrites every commit and requires a force-push."
printf '%s' "Type REWRITE to continue: "
read -r answer
[[ "$answer" == "REWRITE" ]] || exit 1

remote_url=$(git remote get-url origin 2>/dev/null || true)
bundle="../dotfiles-before-private-cleanup-$(date +%Y%m%d_%H%M%S).bundle"
git bundle create "$bundle" --all

git filter-repo --force --invert-paths \
    --path polybar/scripts/psn/npsso \
    --path polybar/scripts/psn/cache \
    --path polybar/scripts/psn/venv \
    --path mpd/database \
    --path mpd/log \
    --path mpd/pid \
    --path mpd/state \
    --path mpd/sticker.sql

if [[ -n "$remote_url" ]] && ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "$remote_url"
fi

cat <<EOF

History rewrite complete.
Backup bundle: $bundle

Inspect the repository, then publish the rewritten history with:
  git push --force-with-lease origin --all
  git push --force-with-lease origin --tags

Anyone with an old clone should delete it and clone again.
EOF

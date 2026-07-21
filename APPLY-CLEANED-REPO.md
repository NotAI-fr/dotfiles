# Applying the cleaned tree to your real clone

The downloadable archive intentionally does **not** contain `.git/`, so it cannot carry the old credential history.

## 1. Rotate the NPSSO credential first

Treat the committed code as exposed. Obtain a replacement before doing anything else.

## 2. Back up your real clone

```bash
cd ~/dotfiles
git status --short
git bundle create ../dotfiles-before-cleanup.bundle --all
```

Commit or stash unrelated work before continuing.

## 3. Copy the cleaned working tree over the clone

Assuming the archive was extracted as `~/Downloads/dotfiles-i3-cleaned/`:

```bash
cd ~/dotfiles
rsync -a --delete --exclude='.git/' \
  ~/Downloads/dotfiles-i3-cleaned/ ./
```

This preserves your real `.git` directory while replacing the repository files, deleting uppercase `Rofi/`, and installing the complete lowercase `rofi/` directory.

Inspect the result:

```bash
git status --short
git diff --stat
git diff -- . ':!polybar/scripts/psn/npsso' ':!polybar/scripts/psn/cache/**'
```

## 4. Commit the cleaned tree

```bash
git add -A
git commit -m "Clean private files and refresh i3 dotfiles"
```

## 5. Remove the private files from every old commit

```bash
sudo pacman -S git-filter-repo
./scripts/purge-private-history.sh
```

Follow the checks in `GIT-HISTORY-CLEANUP.md`, then force-push the rewritten history.

## 6. Recreate local-only files

The cleaned repo contains examples rather than machine-specific files:

```bash
cp -n i3/local.env.example ~/.config/i3/local.env
cp -n polybar/local.env.example ~/.config/polybar/local.env
```

Edit those files for your monitor and weather location. They are ignored by Git.

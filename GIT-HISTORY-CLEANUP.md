# Removing the PlayStation credential from Git history

The credential must be treated as exposed because it was committed. **Replace/rotate the NPSSO code first**, then remove the old file from every Git commit.

## 1. Commit the cleaned working tree

```bash
git add -A
git commit -m "Clean private files and refresh i3 dotfiles"
```

## 2. Install the history-rewrite tool

```bash
sudo pacman -S git-filter-repo
```

## 3. Run the included guarded helper

```bash
./scripts/purge-private-history.sh
```

The helper:

- refuses to run with uncommitted changes;
- creates a full Git bundle backup beside the repository;
- removes the NPSSO file, PSN cache/venv, and MPD state from every commit;
- restores the `origin` remote if `git-filter-repo` removes it;
- does not force-push automatically.

## 4. Inspect and force-push

```bash
git log --all -- polybar/scripts/psn/npsso
git rev-list --objects --all | grep -E 'polybar/scripts/psn/(npsso|cache|venv)|mpd/(database|log|pid|state|sticker.sql)'
```

Both commands should return nothing. Then:

```bash
git push --force-with-lease origin --all
git push --force-with-lease origin --tags
```

All previous clones contain incompatible history. Delete and clone them again rather than pulling normally.

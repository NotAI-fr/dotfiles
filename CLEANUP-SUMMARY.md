# Cleanup summary

## Completed in this version

- Private PSN files removed and ignored
- MPD runtime files removed and ignored
- Complete Rofi configuration migrated from `Rofi/` to `rofi/`
- Installer repaired and tested in an isolated temporary home directory
- i3/X11 package manifests refreshed
- Hard-coded app, monitor, repository, and weather settings centralized
- Backup/sync scripts made i3-focused and repository-location independent
- README rewritten around the current i3 rice
- Screenshot/video capture guide added
- Git-history rewrite helper added
- Shell and Python syntax checks passed

## You still need to do on GitHub

1. Rotate the NPSSO credential.
2. Apply or copy this cleaned tree into your real clone.
3. Commit the changes.
4. Run `./scripts/purge-private-history.sh`.
5. Verify the private paths no longer exist in history.
6. Force-push rewritten branches and tags.
7. Take the new screenshots and video using `SHOWCASE-CAPTURE-GUIDE.md`.
8. Add the GitHub-hosted video URL to `README.md`.

# i3 dotfiles feature inventory and repository audit

This file records what was found in the uploaded repository. It is intended as a maintenance reference, not as the public-facing README.

## i3

### Core appearance

- FiraMono Nerd Font
- Three-pixel tiled and floating borders
- Eight-pixel inner gaps and four-pixel outer gaps
- Theme colours loaded from `i3/colors.conf`
- Floating rules for Pavucontrol, Blueman, and the weather terminal

### Workspaces and window controls

- Five numbered workspaces
- Move focused windows with `Super + Shift + 1…5`
- Close, fullscreen, floating, and tiled/floating focus toggle
- Directional window movement with `Super + Shift + Arrow`
- Native i3 scratchpad bindings

### Launchers and shortcuts

- Kitty
- Nemo
- Helium
- Betterlockscreen
- Rofi app launcher
- Theme/layout system switcher
- Wallpaper picker
- Power menu
- Bluetooth menu
- Rofi calculator
- Notes scratchpad
- Screen recorder
- Config menu
- Region screenshots to file and clipboard

### Hardware/media controls

- PipeWire/WirePlumber volume controls with a 150% ceiling
- Media keys through Playerctl
- Xrandr brightness scripts with Dunst progress OSD
- Current brightness saved under `~/.cache/monitor_brightness`

### Startup

- Polybar
- Autotiling
- Dunst
- Feh
- Picom
- External `HDMI-2` monitor, internal display disabled
- Vesktop
- X cursor reset
- Xresources merge
- `nm-tray`
- XFCE Clipman
- Playerctld daemon

## Rofi

### Main launcher

- Icon-enabled `drun`
- Theme imports for fonts and colours
- Six-hundred-pixel list layout
- Eight visible rows
- Rounded two-pixel accent border
- Theme-aware selection styling

### Wallpaper picker

- Theme-category discovery
- Favourites category
- Three-by-three thumbnail grid
- ImageMagick thumbnail generation
- Thumbnail freshness and pruning
- Current and per-category last wallpaper tracking
- Favourite add/remove
- Random wallpaper
- Open current folder
- Clear/rebuild thumbnail cache
- Theme-derived category colour swatches
- Asynchronous Betterlockscreen update queue
- Automatic search for unused Rofi custom keybindings
- Feh application and Dunst feedback

### Theme switcher

Profiles:

- Monochrome
- Everforest
- Gruvbox
- Catppuccin
- Lavender Light

Targets:

- i3
- Polybar
- Kitty
- Rofi
- rmpc
- Cava
- Dunst
- Wallpaper
- Betterlockscreen
- GTK 3 theme/icon settings
- GTK 4 theme/icon settings

Reloads:

- i3
- XFCE Clipman
- Dunst
- Polybar
- Kitty

### Bar-layout switcher

- Dynamically discovers every `polybar/layouts/*.ini`
- Rewrites the Polybar include
- Restarts Polybar
- Stores the active layout in `~/.config/.active_layout`

Layouts:

- Default
- Floating Islands
- Minimal

### System switcher

- Single entry point for theme switching and Polybar layout switching

### Config menu

- Sectioned Rofi list
- Non-selectable section headlines
- Hides missing paths and empty sections
- Full paths remain searchable through Rofi metadata
- Opens files and directories in Ox inside Kitty
- Roots Ox in the selected directory
- Includes:
  - Polybar main/modules/layouts
  - i3 main/keybinds/startup
  - Rofi folder/main/grid
  - rmpc main/theme
  - Dynamically generated colourscheme entries
  - Kitty main config

### Notes scratchpad

Categories:

- Brain dumps
- Todos
- Ideas
- General notes

Features:

- Timestamped capture
- Prefix routing (`!dump`, `!todo`, `!idea`)
- Newest-first history
- Search through Rofi
- Enter/left click copies content
- Right click deletes an entry
- Right click on a section heading clears that whole category
- Polybar category counts

### Recorder

- Toggle behavior: same shortcut starts/stops
- Selected region or fullscreen
- No audio
- Microphone
- Desktop audio
- Microphone plus desktop audio
- X11 capture through FFmpeg
- H.264/AAC MP4 output under `~/Videos/Recordings`

### Bluetooth menu

- Controller power
- Scan state
- Pairable state
- Discoverable state
- Device list
- Connect/disconnect
- Pair/remove
- Trust/untrust
- Compact status mode for bars

### Power menu

- Power off
- Reboot
- Suspend
- Lock
- Exit i3
- Toggle Picom
- Dynamic game-mode icon based on Picom state

### Other

- Optional Google web-search prompt
- Rofi calculator binding

## Polybar

### Architecture

- `config.ini` loads:
  - current colour pointer
  - one selected layout
  - shared module library
- IPC enabled on every layout
- JetBrainsMono Nerd Font

### Layout modules

#### Default

- Workspaces
- Weather
- Date
- Tray
- Media metadata
- Scratchpad counts
- Night light
- Bluetooth
- Audio
- Microphone
- CPU
- Temperature
- RAM
- Battery
- Dunst state
- Power

#### Floating Islands

- Theme-aware rounded module caps
- Workspaces
- Weather
- Tray
- Date
- Compact previous/play/next controls
- PlayStation presence
- Audio
- Bluetooth
- Power

#### Minimal

- Workspaces
- Weather
- Tray
- Media metadata
- PlayStation presence
- Bluetooth
- Audio
- Temperature
- Date
- Power

### Custom modules

- Theme-aware workspace script
- Weather via `wttr.in`
- Full weather TUI through `wthrr`
- Dunst paused/history count and actions
- MPRIS player metadata and controls
- Scratchpad note counts
- Microphone level and mute
- PlayStation friend presence
- Rofi Bluetooth/power launchers

### PlayStation presence

- PSNAWP API
- Private NPSSO token file
- Friend-list cache
- Presence cache
- File locking
- Conservative refresh intervals
- Online-only and all-friends Rofi views
- Manual presence/friend refresh commands
- Last-good-cache fallback on errors
- Error log

## Visual layer

### Picom

- GLX
- VSync
- Dual-Kawase blur
- Strength 5
- Ten-pixel corner radius
- Rounded border support
- Excludes docks, desktop, Polybar, and Slop where appropriate

### Dunst

- Top-right placement
- Rounded corners
- Accent frame
- Icons
- Progress bars
- Theme colours loaded through a separate include
- Low/normal/critical timeouts

### Kitty

- FiraMono Nerd Font
- Fourteen-point size
- 85% opacity
- No decorations
- Padding
- Theme include
- Remote control
- `Ctrl+V` paste

## Shell

- Zsh history sharing and deduplication
- Case-insensitive completion
- Completion menu
- fzf-tab
- Autosuggestions
- Syntax highlighting
- Starship
- Zoxide
- Package-management aliases
- Fastfetch alias
- Repository backup alias

## Music/video

### MPD/rmpc

- Local MPD daemon
- Mouse-enabled rmpc
- Hot-reloaded config
- Album art and lyrics
- Queue, directories, artists, album artists, albums, playlists, and search
- Custom keyboard controls
- Theme file and separate active colour file

### MPV

- Built-in OSC disabled
- ModernZ Lua interface enabled
- Dedicated ModernZ settings and icon font

## Fastfetch

- Compact bordered information card
- User, host, uptime, OS, kernel, packages, desktop, WM, terminal, shell, CPU, disk, memory, network, and terminal colours

## Maintenance scripts

### `backup.sh`

- Rsyncs local configurations into the repository
- Syncs only the supported i3/X11 configuration and leaves archived Wayland folders untouched
- Commits, rebases on `origin/main`, and pushes automatically

### `sync.sh`

- Refuses to pull with uncommitted changes
- Pulls repository updates with `--ff-only`


## Cleanup applied in the refreshed version

- Removed the tracked NPSSO credential, PSN presence caches, and virtual environment.
- Added Git ignore rules for future PSN credentials/cache/venv files.
- Removed MPD database, log, PID, state, and sticker runtime files.
- Replaced the duplicate `Rofi/` and `rofi/` folders with one complete lowercase `rofi/` source of truth.
- Updated the backup script to sync `~/.config/rofi/` into `rofi/`.
- Repaired `install.sh` for the repository's real root-level directory structure.
- Split dependencies into official `packages.txt` and optional `packages-aur.txt`.
- Removed Hyprland/Wayland packages from the supported i3 package manifest.
- Centralized preferred applications in `i3/modules/00-apps.conf`.
- Moved monitor and brightness values into the ignored local file `i3/local.env`.
- Moved the weather location into the ignored local file `polybar/local.env`.
- Made `backup.sh` and `sync.sh` derive the repository directory from their own location.
- Added a guarded `git-filter-repo` helper and explicit history-cleanup instructions.
- Replaced the public README with an i3/X11-only version.
- Added a detailed screenshot and showcase-video capture guide.

## Remaining manual publishing work

- Rotate the exposed NPSSO token.
- Commit the cleaned tree.
- Run `scripts/purge-private-history.sh` and inspect the result.
- Force-push the rewritten history.
- Capture the Lavender Light screenshot.
- Replace the four old theme images.
- Capture the hero, Polybar layouts, and tool screenshots.
- Record and upload the new showcase video.

# i3 Dotfiles

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=archlinux&logoColor=fff)
![i3](https://img.shields.io/badge/WM-i3-52C0FF)
![X11](https://img.shields.io/badge/Session-X11-FFB300)
![Polybar](https://img.shields.io/badge/Bar-Polybar-8AADF4)
![Rofi](https://img.shields.io/badge/Launcher-Rofi-CBA6F7)

A personal Arch Linux **i3/X11 rice** built around synchronized colour profiles, switchable Polybar layouts, and Rofi-powered desktop tools.

> Hyprland and other Wayland folders are retained only as archived backups. The supported and documented setup in this repository is i3/X11.

## Showcase

<!-- Replace this comment with the new GitHub-hosted MP4 URL after recording it. -->

The current screenshots below are being replaced using [`SHOWCASE-CAPTURE-GUIDE.md`](SHOWCASE-CAPTURE-GUIDE.md).

| Monochrome | Everforest | Gruvbox | Catppuccin Mocha |
|---|---|---|---|
| ![Monochrome](assets/themes/monochrome.png) | ![Everforest](assets/themes/everforest.png) | ![Gruvbox](assets/themes/gruvbox.png) | ![Catppuccin Mocha](assets/themes/catppuccin-mocha.png) |

**Lavender Light** is also included; its new screenshot should be saved as `assets/themes/lavender-light.png`.

## At a glance

| Component | Choice |
|---|---|
| Window manager | i3 |
| Bar | Polybar |
| Launcher and menus | Rofi |
| Terminal | Kitty |
| Shell | Zsh + Starship |
| Compositor | Picom |
| Notifications | Dunst |
| File manager | Nemo |
| Lock screen | Betterlockscreen |
| Music | MPD + rmpc |
| Video | MPV + ModernZ |
| Editor used by the config menu | Ox |

## Highlights

### Synchronized theme profiles

The Rofi switcher coordinates i3 borders, Polybar, Kitty, Rofi, rmpc, Cava, Dunst, GTK theme/icon settings, wallpaper, and Betterlockscreen.

Included profiles:

- Monochrome
- Everforest
- Gruvbox
- Catppuccin Mocha
- Lavender Light

### Three Polybar layouts

- **Default:** full system, media, notification, note, and hardware modules.
- **Floating Islands:** rounded colour-backed modules on a transparent canvas.
- **Minimal:** compact workspaces, weather, media, PSN presence, audio, temperature, date, and power.

Use `Super + T` to open the combined theme/layout switcher.

### Rofi desktop toolkit

| Shortcut | Tool |
|---|---|
| `Super + Space` | Application launcher |
| `Super + T` | Theme and Polybar-layout switcher |
| `Super + W` | Thumbnail wallpaper picker |
| `Super + P` | Power/Picom game-mode menu |
| `Super + B` | Bluetooth manager |
| `Super + N` | Categorized notes scratchpad |
| `Super + Shift + P` | Region/fullscreen screen recorder |
| `Super + Shift + C` | Sectioned config menu opening files in Ox |
| `Super + X` | Rofi calculator |
| `Super + S` | Region screenshot to file and clipboard |

The wallpaper picker includes per-theme categories, favourites, random selection, thumbnail caching, current-wallpaper tracking, folder opening, and asynchronous Betterlockscreen updates.

### Polybar integrations

- Clickable i3 workspaces
- Weather temperature and `wthrr` terminal forecast
- MPRIS media metadata and playback controls
- Audio output and microphone controls
- CPU, RAM, temperature, battery, date, tray, and night-light modules
- Dunst pause/history controls
- Scratchpad category counts
- Bluetooth and power launchers
- Optional PlayStation friend presence with conservative caching

> The PlayStation module uses a private NPSSO credential. Its token, cache, and virtual environment are ignored by Git.

### i3 workflow

- Five workspaces
- Autotiling
- Gaps and three-pixel borders
- Fullscreen, floating, and scratchpad controls
- Floating rules for Pavucontrol, Blueman, and weather
- Media keys through Playerctl and WirePlumber
- External-monitor brightness OSD
- Picom dual-Kawase blur and rounded corners

### Terminal, music, and video

- Zsh shared/deduplicated history, `fzf-tab`, autosuggestions, syntax highlighting, Starship, and Zoxide
- Kitty opacity, Nerd Font, theme include, and normal `Ctrl+V` paste
- rmpc queue, library, artists, albums, playlists, search, lyrics, album art, mouse support, and hot reload
- MPV with the ModernZ on-screen controller

## Selected i3 shortcuts

| Shortcut | Action |
|---|---|
| `Super + Q` | Kitty |
| `Super + E` | Nemo |
| `Super + R` | Browser |
| `Super + L` | Lock |
| `Super + C` | Close focused window |
| `Super + F` | Fullscreen |
| `Super + Shift + F` | Floating toggle |
| `Super + 1…5` | Switch workspace |
| `Super + Shift + 1…5` | Move window to workspace |
| `Super + -` | Show/cycle scratchpad |
| `Super + Shift + -` | Send window to scratchpad |
| `Super + Shift + A/D` | External-monitor brightness |
| `Super + Shift + R` | Restart Polybar and reload i3 |

Application commands are centralized in `i3/modules/00-apps.conf`.

## Repository layout

```text
dotfiles/
├── i3/                 # WM config, app variables, startup, keybinds, monitor scripts
├── polybar/            # Shared modules, three layouts, media/weather/PSN helpers
├── rofi/               # Launcher themes and desktop utility scripts
├── colorschemes/       # Five synchronized desktop profiles
├── Walls/              # Wallpapers grouped by theme
├── kitty/              # Terminal config and active theme include
├── dunst/              # Notification styling
├── picom/              # Blur and rounded-corner compositor settings
├── rmpc/ and mpd/      # Music client and daemon
├── mpv/                # MPV and ModernZ
├── fastfetch/          # System-information layout
├── assets/             # README media
├── packages.txt        # Official Arch dependencies
├── packages-aur.txt    # Optional AUR dependencies
├── install.sh          # Safe config deployment; packages are opt-in
├── backup.sh           # i3-focused backup and Git push
└── sync.sh             # Fast-forward-only Git pull
```

## Installation

Review scripts before running them. Existing destinations are moved into a timestamped directory under `~/.dotfiles_backup/`.

```bash
git clone https://github.com/NotAI-fr/dotfiles.git
cd dotfiles
chmod +x install.sh

# Preview config deployment
./install.sh --dry-run

# Deploy configs only
./install.sh

# Install dependencies and deploy
./install.sh --packages
```

The installer uses the actual root-level repository layout and lowercase `rofi/` directory.

After installation, edit:

```text
~/.config/i3/local.env
~/.config/i3/modules/00-apps.conf
~/.config/polybar/local.env
```

These files control the monitor/output settings, preferred applications, and weather location without requiring edits across several scripts.

## Optional PlayStation module

```bash
cd ~/.config/polybar/scripts/psn
python -m venv venv
venv/bin/pip install psnawp
cp npsso.example npsso
chmod 600 npsso
```

Replace the placeholder token, then run:

```bash
./psn-friends test-auth
./psn-friends refresh-friends
```

## Maintenance

```bash
./backup.sh  # Copy active i3 configs into this repo, commit, rebase, push
./sync.sh    # Pull only when the working tree is clean and fast-forwardable
```

The backup script deliberately leaves archived Wayland folders untouched.

## Privacy and history cleanup

If an NPSSO code was ever committed, deleting the current file is not enough. Rotate the token and follow [`GIT-HISTORY-CLEANUP.md`](GIT-HISTORY-CLEANUP.md) before the next public push.

## Customization map

| Change | File |
|---|---|
| Preferred apps | `i3/modules/00-apps.conf` |
| Monitor/output | `i3/local.env` |
| i3 shortcuts | `i3/modules/keybinds.conf` |
| Startup programs | `i3/modules/startup.conf` |
| Weather location | `polybar/local.env` |
| Polybar layout | `polybar/config.ini` or the Rofi layout switcher |
| Shared Polybar modules | `polybar/modules.ini` |
| Rofi appearance | `rofi/config.rasi`, `rofi/grid.rasi` |
| Theme profiles | `colorschemes/<theme>/` |
| Wallpaper picker | `rofi/wallpaper-picker.sh` |
| Terminal | `kitty/kitty.conf` |
| Blur/rounding | `picom/picom.conf` |
| Notifications | `dunst/dunstrc` |
| rmpc | `rmpc/config.ron` |

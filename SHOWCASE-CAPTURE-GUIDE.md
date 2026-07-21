# Screenshot and showcase-video capture guide

This guide matches the asset paths used by the refreshed README.

## Before recording anything

1. **Use one consistent 16:9 resolution.** Your current 1360×768 display is fine; 1920×1080 is also fine if it works reliably. Do not mix dimensions between theme shots.
2. **Use PNG for screenshots.**
3. Close browser tabs, chats, email, and personal files.
4. Clear or pause notifications before arranging a shot:
   ```bash
   dunstctl close-all
   ```
5. Hide private PlayStation names, account details, terminal tokens, IP addresses, and home-directory content.
6. Use a copyright-safe track or record the video muted.
7. Keep the pointer out of the centre of the frame.
8. Use the same window layout for every theme-comparison screenshot.
9. Let theme/wallpaper/Polybar reloads finish before capturing.
10. Temporarily stop anything that causes changing counters or popups if it distracts from the shot.

Your existing screenshot shortcut is:

```text
Super + S
```

It saves a selected area under `~/Pictures/screenshots/` and copies it to the clipboard.

## Required README screenshots

### 1. Hero image

**Output:**

```text
assets/showcase/hero.png
```

**Recommended setup:**

- Catppuccin Mocha or whichever theme best represents the rice
- Floating Islands Polybar
- Theme-matching default wallpaper
- Two balanced Kitty windows:
  - Left: `fastfetch`
  - Right: `rmpc`, `btop`, or Ox editing a clean config
- Leave enough wallpaper visible to show the blur/transparency
- Have music playing so the Polybar player controls look active
- Keep the PSN module visible, but do not expose friend names

The hero should communicate the whole setup in one frame: wallpaper, i3 borders/gaps, Polybar, Kitty transparency, font, and one useful TUI.

### 2. Five theme-comparison images

Overwrite the existing four images and add Lavender Light:

```text
assets/themes/monochrome.png
assets/themes/everforest.png
assets/themes/gruvbox.png
assets/themes/catppuccin-mocha.png
assets/themes/lavender-light.png
```

Use exactly the same arrangement in every image:

- Floating Islands layout
- One Kitty window running `fastfetch`
- One second window running the same program each time
- Theme default wallpaper
- Same workspace and window sizes
- Same music/player state when possible

This makes the palette differences obvious rather than comparing unrelated layouts.

### 3. Polybar-layout comparison

Create:

```text
assets/showcase/layouts/default.png
assets/showcase/layouts/floating-islands.png
assets/showcase/layouts/minimal.png
```

Use one theme and one wallpaper for all three. Crop each screenshot so the bar is large enough to inspect, while retaining a little desktop context.

Activate the picker with:

```bash
~/.config/rofi/bar-layout-switcher.sh
```

### 4. Tool screenshots

Create at least these four:

```text
assets/showcase/tools/system-switcher.png
assets/showcase/tools/wallpaper-picker.png
assets/showcase/tools/config-menu.png
assets/showcase/tools/scratchpad.png
```

**System switcher:** show the main Theme/Layout choice.

**Wallpaper picker:** use a theme category with nine attractive thumbnails visible. Highlight one item so the border and active style show.

**Config menu:** show several section headings and entries. The Polybar, i3, Rofi, colourscheme, and Kitty sections should be visible if possible.

**Scratchpad:** show the history screen with harmless sample entries in at least three categories:
- `!todo Finish README`
- `!idea Add a compact Polybar layout`
- A general note

Delete the sample notes afterward.

### 5. Optional feature shots

These are useful for the full gallery but not required for the README front page:

```text
assets/showcase/tools/rmpc.png
assets/showcase/tools/notifications.png
assets/showcase/tools/power-menu.png
assets/showcase/tools/bluetooth.png
assets/showcase/tools/psn-friends.png
assets/showcase/tools/ox-config.png
assets/showcase/tools/recorder.png
```

For `psn-friends.png`, blur or replace all friend names before committing it.

For a controlled Dunst screenshot:

```bash
notify-send -u low "Theme switched" "Catppuccin Mocha is now active"
notify-send -u normal "Music" "Now playing through the MPRIS module"
notify-send -u critical "Example alert" "Critical notifications stay visible"
```

## Screenshot composition checklist

A strong screenshot should show:

- The whole Polybar without clipping
- Clean gaps around windows
- A readable terminal font
- The theme's accent colour in i3 borders and UI selections
- Enough wallpaper to make transparency visible
- No menus partially outside the screen
- No private account names or tokens
- No terminal error output
- No unnecessary empty windows

Avoid:

- Capturing the mouse over important text
- Mixing multiple themes in one screenshot
- Showing stale notifications
- Using a wallpaper that makes text unreadable
- Overfilling the screen with five different apps
- Extremely cropped screenshots that hide the desktop context

## Showcase video

### Recommended final length

**55–75 seconds**

Short enough to watch quickly, but long enough to show that the rice is functional rather than only a static theme.

### Capture settings

Your Rofi recorder can be opened with:

```text
Super + Shift + P
```

Choose:

```text
Fullscreen
Muted
```

Muted is safest unless you have a copyright-safe track. The current script records X11 at 30 FPS using H.264.

For the final export, use:

- MP4
- H.264
- 30 FPS
- 16:9
- `yuv420p`
- No mouse-highlight effects
- Quick cuts, but no fast unreadable transitions

### Storyboard

#### 0:00–0:05 — Clean opening

- Start on the hero desktop.
- Leave it still for roughly two seconds.
- Open Kitty and run `fastfetch`, or begin with the arranged hero layout already visible.

#### 0:05–0:18 — Theme switching

- Press `Super + T`.
- Choose **Change Theme**.
- Show three quick switches:
  1. Monochrome
  2. Gruvbox or Everforest
  3. Catppuccin or Lavender Light
- Pause roughly two seconds after each choice so the wallpaper, borders, Kitty, Rofi, Dunst, and Polybar changes are visible.
- End this section on the theme used by the hero image.

#### 0:18–0:29 — Polybar layouts

- Open `Super + T`.
- Choose **Change Bar Layout**.
- Switch:
  1. Default
  2. Minimal
  3. Floating Islands
- Leave Floating Islands active for the rest of the video.

#### 0:29–0:40 — Wallpaper picker

- Press `Super + W`.
- Enter the active theme category.
- Move through the thumbnail grid.
- Use the Random shortcut once or choose a wallpaper manually.
- Reopen the picker briefly to show the favourites category.

Do not spend time waiting for thumbnails to generate during the final recording. Build the cache beforehand.

#### 0:40–0:49 — Desktop tools

Show two of these, not all of them:

- `Super + Shift + C` → select an i3 or Polybar config → Ox opens in Kitty
- `Super + N` → capture a sample todo → reopen history
- `Super + B` → show the Bluetooth menu
- `Super + P` → show the power/game-mode grid, then cancel

Use quick cuts if opening an application takes too long.

#### 0:49–0:60 — Media and Polybar interaction

- Start or resume a song.
- Demonstrate the centre player controls.
- Open rmpc for a few seconds.
- Click one non-private Polybar action such as weather, notifications, or audio.

The PSN friends menu should only appear if the names have been replaced or safely blurred in editing.

#### 0:60–0:68 — Closing frame

- Close menus.
- Return to the clean hero desktop.
- Leave the frame still for two to three seconds.
- Fade out.

### Editing advice

- Cut out loading time and accidental menu navigation.
- Keep text on screen long enough to be read.
- Use simple cuts or a short crossfade; the theme switches provide enough visual movement.
- Avoid adding a large title over the desktop. A small opening caption such as `i3 • Polybar • Rofi` is enough.
- If you add music, lower it and avoid tracks that could cause copyright claims.
- Do not speed up the whole recording; speed up only dead time.

## Uploading the video to GitHub

1. Open `README.md` in GitHub's web editor.
2. Drag the final MP4 into the text area.
3. Wait for GitHub to create an attachment URL.
4. Put that URL on its own line under `## Showcase`.
5. Remove the placeholder HTML comment.
6. Preview the README before committing.

## Final asset checklist

```text
assets/
├── showcase/
│   ├── hero.png
│   ├── layouts/
│   │   ├── default.png
│   │   ├── floating-islands.png
│   │   └── minimal.png
│   └── tools/
│       ├── system-switcher.png
│       ├── wallpaper-picker.png
│       ├── config-menu.png
│       └── scratchpad.png
└── themes/
    ├── monochrome.png
    ├── everforest.png
    ├── gruvbox.png
    ├── catppuccin-mocha.png
    └── lavender-light.png
```

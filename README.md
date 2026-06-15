# Dotfiles

My personal dotfiles and system configuration. 

## 📸 Showcase


https://github.com/user-attachments/assets/d86452e0-7f1d-4313-bf8e-2ff1d5dd88ef


## 📸 Screenshots

| Monochrome | Everforest | Gruvbox | Catppuccin Mocha |
|--- |--- |--- |--- |
| ![Monochrome](assets/themes/monochrome.png) | ![Everforest](assets/themes/everforest.png) | ![Gruvbox](assets/themes/gruvbox.png) | ![Catppuccin Mocha](assets/themes/catppuccin-mocha.png) |

<br>

👉 [**For More Screenshots, Go To The Assets Folder**](./assets)

## 🛠️ Setup Core

* **WM / Compositors:** i3 & Hyprland
* **Terminals:** Kitty
* **Status Bars:** Polybar & Waybar
* **Launchers:** Rofi
* **Notifications:** Dunst
* **Media & Audio:** MPD, rmpc, & MPV
* **System Info:** Fastfetch

## ✨ Environment Features

* **🎨 Theme Switcher:** Seamless switching between Monochrome, Everforest, Gruvbox, and Catppuccin Mocha colorscapes.
* **🖼️ Wallpaper Switcher:** Handled via feh, pulling from categorized assets in the `Walls` directory.
* **⚙️ Custom Tool Configurations:** Tailored layouts for both X11 and Wayland environments, complete with custom notification schemes and status modules.

## 📂 File Structure

```text
dotfiles/
├── colorschemes/  # Centralized color palette configurations
├── dunst/         # Notification daemon styles
├── fastfetch/     # System info layout configuration
├── hypr/          # Hyprland compositor settings
├── i3/            # i3 window manager configurations
├── kitty/         # Terminal emulator profiles and styles
├── mpd/           # Music Player Daemon settings
├── mpv/           # Media player rules and keybinds
├── picom/         # X11 compositor rules (blur and shadows)
├── polybar/       # X11 status bar modules and styling
├── rmpc/          # Music player client configurations
├── Rofi/          # Primary Rofi launcher themes
├── rofi/          # Alternative/fallback launcher styles
├── Walls/         # Categorized wallpaper library
├── waybar/        # Wayland status bar layouts
├── assets/        # assets such as shocase screenshots
└── wlogout/       # Wayland logout menu configuration

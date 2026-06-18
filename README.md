# Dotfiles

My personal dotfiles and system configuration. 

## 📸 Showcase



https://github.com/user-attachments/assets/8ce555a0-0ac7-45eb-b75c-b3f582bb57f7



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

* ## 🚀 Installation & Deployment

This configuration includes a deployment script to easily bootstrap dependencies (including AUR packages) and clone configurations onto any fresh Arch Linux system. All standard and AUR packages are enabled by default in `packages.txt`.

```bash
git clone [https://github.com/NotAI-fr/dotfiles.git](https://github.com/NotAI-fr/dotfiles.git)
cd dotfiles
chmod +x install.sh
./install.sh
```

* ## 🖼️ Wallpapers

Wallpaper categories for each colorscheme

* ![](https://img.shields.io/badge/-%20-1a1a1a?style=flat-square)![](https://img.shields.io/badge/-%20-444444?style=flat-square)![](https://img.shields.io/badge/-%20-ffffff?style=flat-square) [**Monochrome**](./Walls/monochrome)
* ![](https://img.shields.io/badge/-%20-1e1e2e?style=flat-square)![](https://img.shields.io/badge/-%20-cba6f7?style=flat-square)![](https://img.shields.io/badge/-%20-89b4fa?style=flat-square) [**Catppuccin**](./Walls/catppuccin)
* ![](https://img.shields.io/badge/-%20-282828?style=flat-square)![](https://img.shields.io/badge/-%20-fe8019?style=flat-square)![](https://img.shields.io/badge/-%20-fabd2f?style=flat-square) [**Gruvbox**](./Walls/gruvbox)
* ![](https://img.shields.io/badge/-%20-2b3339?style=flat-square)![](https://img.shields.io/badge/-%20-a7c080?style=flat-square)![](https://img.shields.io/badge/-%20-dbbc7f?style=flat-square) [**Everforest**](./Walls/everforest)

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
│   ├── catppuccin/
│   ├── everforest/
│   ├── gruvbox/
│   └── monochrome/
├── waybar/        # Wayland status bar layouts
├── assets/        # assets such as shocase screenshots
├── wlogout/       # Wayland logout menu configuration
├── packages.txt   # Core and optional opt-in dependency list
└── install.sh     # Automated package sync and configuration copy script

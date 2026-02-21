# .dotfiles

Hyprland rice for CachyOS. Catppuccin Mocha, frosted glass, the works.

## Stack

| Role | Tool |
|---|---|
| Compositor | Hyprland |
| Bar | HyprPanel |
| Launcher | Anyrun |
| Terminal | Kitty |
| Shell | Fish + Starship |
| Notifications | SwayNC |
| Lock screen | Swaylock-effects |
| Display manager | SDDM (astronaut theme) |
| Wallpaper | swww |
| File manager | Yazi (TUI) / Dolphin (GUI) |
| Editor | Zed / Micro |
| Video | mpv |
| Browsers | Firefox, Zen |
| Theming | Flavours (base16) + Matugen |
| Colour scheme | Catppuccin Mocha |

## Fresh install

Tested on a headless CachyOS install (no DE selected in the installer).

```bash
sudo pacman -S git
git clone https://github.com/mofumail/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup.sh
```

Reboot. SDDM will start, log in, Hyprland loads with everything configured.

### What setup.sh does

1. Installs `git` and `base-devel` if missing
2. Clones / updates this repo to `~/.dotfiles`
3. Builds `paru` (AUR helper) and installs all packages from `packages/paru.txt`
4. Symlinks every config dir into `~/.config/` (existing dirs are backed up with a timestamp)
5. Applies Catppuccin Mocha via `flavours apply mocha`, installs browser chrome theme into Firefox and Zen profiles
6. Copies the wallpaper, installs the SDDM astronaut theme, enables `sddm.service`
7. Sets fish as the default shell, installs Fisher and the `done` notification plugin

### After first login

- Wallpaper sets itself automatically (via `exec-once` in `hyprland.conf`)
- **Browsers** — if Firefox/Zen hadn't been launched before setup ran, open each once then rerun:
  ```bash
  ~/.dotfiles/setup.sh --no-packages --no-sddm
  ```
- **Dev environments** — run `uv` and `pyenv install <version>` once to initialise them

### Options

```
--dry-run        Print what would happen without making changes
--no-packages    Skip paru + package installation
--no-sddm        Skip SDDM theme and service setup
--no-wallpaper   Skip wallpaper installation
--no-fisher      Skip Fisher and fish plugin installation
```

## Updating configs

Since all `~/.config/*` entries are symlinks into this repo, any change you make in your running system is already in the repo. Just commit:

```bash
cd ~/.dotfiles
git add -p   # review changes
git commit -m "..."
git push
```

## Colour schemes

Flavours uses base16. To switch:

```bash
flavours list          # browse available schemes
flavours apply dracula # example
```

Templates live in `flavours/templates/` and rewrite kitty, waybar, anyrun, swaylock, and hyprland on apply.

## Structure

```
.dotfiles/
├── anyrun/         launcher config + CSS
├── browser/        shared userChrome.css + user.js (Firefox & Zen)
├── fish/           shell config, conf.d, functions
├── flavours/       colour scheme manager + base16 templates
├── hypr/           Hyprland config + keybind reference
├── hyprpanel/      bar config
├── kitty/          terminal config
├── micro/          editor settings + Catppuccin themes
├── mpv/            media player config
├── swaylock/       lock screen config
├── swaync/         notification centre config
├── waybar/         (legacy, kept for reference)
├── yazi/           file manager keymap
├── zed/            editor settings
├── assets/
│   └── wallpaper.jpg
├── packages/
│   └── paru.txt    full package list
├── system/
│   └── sddm/       astronaut theme + grain.jpg background
└── setup.sh        bootstrap script
```

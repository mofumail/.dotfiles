# Hyprland Rice - Session Log

## System
- **Distro**: CachyOS (Arch-based)
- **WM**: Hyprland
- **Shell**: fish (default) + starship prompt
- **AUR helper**: paru
- **User**: mofu

## Installed Packages
Installed via `paru -S --needed`:
- **waybar** - status bar
- **swww** - animated wallpaper daemon
- **swaync** - notification center
- **swaylock-effects-git** - lockscreen with blur/effects
- **starship** - cross-shell prompt
- **anyrun-git** - app launcher (AUR)
- **ttf-jetbrains-mono-nerd** - nerd font (terminal + bar icons)
- **otf-font-awesome** - icon font (waybar)
- **playerctl** - media key control
- **grim** - screenshot tool
- **slurp** - region selection for screenshots

Already present on fresh CachyOS install:
- kitty, alacritty, wofi, fastfetch, fish, git, ffmpeg, curl, wget, base-devel

## Config Files Created/Modified

### ~/.config/hypr/hyprland.conf (modified)
- Added `exec-once` autostart: waybar, swww-daemon, swaync
- Disabled default Hyprland logo/wallpaper (`force_default_wallpaper = 0`, `disable_hyprland_logo = true`)
- Added keybinds: lock screen (SUPER+L), screenshots (Print), notification center (SUPER+N)
- $menu already set to `anyrun`
- Blur: size 8, 3 passes, new_optimizations on, xray off (frosted glass quality)
- Shadow: range 20, render_power 2, semi-transparent color (soft floating shadow)
- Inactive window opacity: 0.92 (subtle transparency on unfocused windows)
- Layer rules: `blur` and `ignorezero` for waybar (enables blur behind the bar)

### ~/.config/waybar/config.jsonc (created)
- Top bar, 34px height
- Left: workspaces, window title
- Center: clock
- Right: pulseaudio, network, cpu, memory, battery, tray, swaync widget
- Catppuccin Mocha color base in style.css

### ~/.config/waybar/style.css (restyled)
- Floating pill bar: 8px top margin, 12px side margins, 14px border-radius
- Transparent background (rgba 30,30,46 @ 0.7) with Hyprland blur behind
- Subtle 1px border (blue @ 0.15 opacity)
- Module pills: individual rounded capsule backgrounds (rgba 24,24,37 @ 0.5, 10px radius)
- Per-module Catppuccin accent colors: pulseaudio pink, network teal, cpu blue, memory mauve, battery green
- Active workspace: solid blue (#89b4fa) pill with dark text
- Hover effects on interactive modules
- Critical battery blink animation
- Tooltips: rounded, blurred dark background

### ~/.config/anyrun/config.ron (created)
- Centered, 600px wide, overlay layer
- Plugins: applications, shell, rink (calculator), symbols, websearch

### ~/.config/anyrun/style.css (created)
- Translucent dark background, rounded corners
- Matches Catppuccin Mocha palette

### ~/.config/swaync/config.json (created)
- Right/top position, 400px wide
- Widgets: title bar with clear-all, DnD toggle, notifications list

### ~/.config/swaylock/config (created)
- Screenshot + blur effect (7x5) + vignette
- Clock overlay with time/date
- Catppuccin Mocha ring/indicator colors
- 2 second grace period

### ~/.config/kitty/kitty.conf (created)
- Font: JetBrains Mono Nerd Font @ 11pt
- Background opacity: 0.85 (frosted glass with Hyprland blur)
- Window padding: 12px all sides
- Cursor: beam, 1.5px thick, blinking
- Tab bar: powerline style (slanted), bottom edge
- Full Catppuccin Mocha 16-color palette + selection/cursor/tab/mark colors
- No audio bell, no close confirmation
- Default window size: 120 columns x 36 lines

### ~/.config/fish/config.fish (modified)
- Added `starship init fish | source` at the end

## What's NOT Done Yet (next steps)
- Wallpaper not yet set (swww is ready, needs `swww img /path/to/wallpaper`)
- Starship prompt not themed (using defaults)
- No window rules for specific apps (e.g., float file dialogs)
- Hyprland animations are still stock defaults (could be tuned)
- swaync styling untouched (functional but not themed beyond defaults)

#!/usr/bin/env bash
# setup.sh — bootstrap a fresh CachyOS install with mofumail's dotfiles
#
# Quick start (run from anywhere):
#   bash <(curl -fsSL https://raw.githubusercontent.com/mofumail/.dotfiles/main/setup.sh)
#
# Or if you already cloned the repo:
#   ./setup.sh
#
set -euo pipefail

# ── Flags ──────────────────────────────────────────────────────────────────
DRY_RUN=0
SKIP_PACKAGES=0
SKIP_SDDM=0
SKIP_WALLPAPER=0
SKIP_FISHER=0

usage() {
  cat <<'EOF'
setup.sh — bootstrap a fresh CachyOS install with mofumail's dotfiles

Usage: setup.sh [options]

Options:
  --dry-run        Print what would happen without making changes
  --no-packages    Skip package installation (paru + paru.txt)
  --no-sddm        Skip SDDM theme & service setup
  --no-wallpaper   Skip wallpaper installation
  --no-fisher      Skip Fisher + fish plugin installation
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=1 ;;
    --no-packages) SKIP_PACKAGES=1 ;;
    --no-sddm)     SKIP_SDDM=1 ;;
    --no-wallpaper) SKIP_WALLPAPER=1 ;;
    --no-fisher)   SKIP_FISHER=1 ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done

# ── Helpers ────────────────────────────────────────────────────────────────
G='\e[1;32m' Y='\e[1;33m' R='\e[1;31m' B='\e[1;34m' D='\e[2m' N='\e[0m'

log()  { printf "${G}[setup]${N} %s\n" "$*"; }
warn() { printf "${Y}[warn]${N}  %s\n" "$*"; }
die()  { printf "${R}[error]${N} %s\n" "$*" >&2; exit 1; }
step() { printf "\n${B}══ %s${N}\n" "$*"; }

run() {
  if (( DRY_RUN )); then
    printf "${D}[dry] %s${N}\n" "$*"
    return 0
  fi
  "$@"
}

ensure_sudo() {
  (( DRY_RUN )) && return 0
  sudo -v || die "sudo access required"
}

# ── Sanity checks ──────────────────────────────────────────────────────────
[[ ${EUID} -eq 0 ]] && die "Run as your normal user, not root."

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID_LIKE:-}" != *arch* && "${ID:-}" != *arch* && "${ID:-}" != cachyos ]]; then
    warn "This script targets CachyOS / Arch Linux. Detected: ${ID:-unknown}."
    warn "Continuing anyway — some steps may fail on other distros."
  fi
fi

DOTFILES_REPO="https://github.com/mofumail/.dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# If the script is already inside the cloned repo, use it directly.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [[ -d "$SCRIPT_DIR/.git" && -f "$SCRIPT_DIR/hypr/hyprland.conf" ]]; then
  DOTFILES_DIR="$SCRIPT_DIR"
fi

# ══════════════════════════════════════════════════════════════════════════════
step "1/7  Bootstrap — git & base-devel"
# ══════════════════════════════════════════════════════════════════════════════

ensure_sudo

if ! command -v git &>/dev/null; then
  log "Installing git and base-devel"
  run sudo pacman -S --needed --noconfirm git base-devel
else
  log "git $(git --version | awk '{print $3}') already present"
fi

# ══════════════════════════════════════════════════════════════════════════════
step "2/7  Dotfiles — clone / update"
# ══════════════════════════════════════════════════════════════════════════════

if [[ "$DOTFILES_DIR" == "$SCRIPT_DIR" ]]; then
  log "Running from inside dotfiles repo at $DOTFILES_DIR — skipping clone"
elif [[ -d "$DOTFILES_DIR/.git" ]]; then
  log "Repo already exists — pulling latest"
  run git -C "$DOTFILES_DIR" pull --ff-only
else
  log "Cloning $DOTFILES_REPO → $DOTFILES_DIR"
  run git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# ══════════════════════════════════════════════════════════════════════════════
step "3/7  Packages — paru + paru.txt"
# ══════════════════════════════════════════════════════════════════════════════

if (( ! SKIP_PACKAGES )); then
  ensure_sudo

  # base-devel is required by makepkg (paru build)
  run sudo pacman -S --needed --noconfirm base-devel

  if ! command -v paru &>/dev/null; then
    log "Building paru from AUR"
    run rm -rf /tmp/paru-build
    run git clone https://aur.archlinux.org/paru.git /tmp/paru-build
    if (( DRY_RUN )); then
      log "[dry] Would run: cd /tmp/paru-build && makepkg -si --noconfirm"
    else
      (cd /tmp/paru-build && makepkg -si --noconfirm)
    fi
    run rm -rf /tmp/paru-build
  else
    log "paru already installed"
  fi

  PKG_FILE="$DOTFILES_DIR/packages/paru.txt"
  [[ -f "$PKG_FILE" ]] || die "Package list not found: $PKG_FILE"

  mapfile -t PKGS < <(grep -vE '^\s*(#|$)' "$PKG_FILE")
  if [[ ${#PKGS[@]} -gt 0 ]]; then
    log "Installing ${#PKGS[@]} packages via paru"
    # --skipreview: skip PKGBUILD review prompts for a fully automated install
    run paru -S --needed --noconfirm --skipreview "${PKGS[@]}"
  else
    warn "Package list is empty: $PKG_FILE"
  fi

  # Initialise rustup — creates ~/.cargo/env.fish (sourced by fish conf.d)
  if command -v rustup &>/dev/null; then
    if ! rustup toolchain list 2>/dev/null | grep -q stable; then
      log "Setting up Rust stable toolchain via rustup"
      run rustup default stable
    else
      log "Rust stable toolchain already installed"
    fi
  fi

else
  log "Skipping packages (--no-packages)"
fi

# ══════════════════════════════════════════════════════════════════════════════
step "4/7  Configs — symlink dotfiles → ~/.config"
# ══════════════════════════════════════════════════════════════════════════════

# These top-level entries in the repo are NOT config dirs and must not be linked.
CONFIG_EXCLUDES=(
  ".git"
  ".gitignore"
  "assets"
  "browser"
  "packages"
  "system"
  "setup.sh"
  "README.md"
)

is_excluded() {
  local name="$1"
  for ex in "${CONFIG_EXCLUDES[@]}"; do
    [[ "$name" == "$ex" ]] && return 0
  done
  return 1
}

backup_path() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  local dest="${path}.bak-$(date +%Y%m%d-%H%M%S)"
  log "  backup  $path → $(basename "$dest")"
  run mv "$path" "$dest"
}

link_config() {
  local src="$1" dest="$2"
  backup_path "$dest"
  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
  log "  linked  ~/.config/$(basename "$dest")"
}

run mkdir -p "$HOME/.config"

shopt -s nullglob
for entry in "$DOTFILES_DIR"/*; do
  name="$(basename "$entry")"
  is_excluded "$name" && continue
  [[ -d "$entry" || -f "$entry" ]] && link_config "$entry" "$HOME/.config/$name"
done
shopt -u nullglob

# Set up XDG user dirs (Downloads, Documents, Pictures, etc.)
if command -v xdg-user-dirs-update &>/dev/null; then
  log "Updating XDG user directories"
  run xdg-user-dirs-update
fi

# ══════════════════════════════════════════════════════════════════════════════
step "5/7  Theming — flavours + browser chrome"
# ══════════════════════════════════════════════════════════════════════════════

# Apply catppuccin mocha colour scheme via flavours
if command -v flavours &>/dev/null; then
  log "Applying catppuccin mocha colour scheme"
  run flavours apply mocha
else
  warn "flavours not found — skipping colour scheme apply"
fi

# Install shared browser chrome (userChrome.css + user.js) for Firefox and Zen.
# Both browsers use an identical frosted Catppuccin Mocha theme.
# Profiles only exist after the browser has been launched at least once, so
# this step is skipped with a reminder if no profile is found yet.
install_browser_chrome() {
  local browser="$1"   # display name
  local profile_dir="$2"

  if [[ -z "$profile_dir" || ! -d "$profile_dir" ]]; then
    warn "$browser: no profile found — launch it once then rerun setup.sh --no-packages --no-sddm"
    return 0
  fi

  local chrome_dir="$profile_dir/chrome"
  log "$browser: installing chrome → $chrome_dir"
  run mkdir -p "$chrome_dir"
  run cp -f "$DOTFILES_DIR/browser/chrome/userChrome.css" "$chrome_dir/userChrome.css"
  run cp -f "$DOTFILES_DIR/browser/user.js" "$profile_dir/user.js"
}

BROWSER_SRC="$DOTFILES_DIR/browser"
if [[ -d "$BROWSER_SRC" ]]; then
  # Firefox — match *.default-release or *.default
  FF_PROFILE=""
  for p in ~/.mozilla/firefox/*.default-release ~/.mozilla/firefox/*.default; do
    [[ -d "$p" ]] && { FF_PROFILE="$p"; break; }
  done
  install_browser_chrome "Firefox" "$FF_PROFILE"

  # Zen — match *.Default* (Zen uses "Default (release)" naming)
  ZEN_PROFILE=""
  for p in ~/.zen/*.Default*; do
    [[ -d "$p" ]] && { ZEN_PROFILE="$p"; break; }
  done
  install_browser_chrome "Zen" "$ZEN_PROFILE"
else
  warn "browser/ dir not found in dotfiles — skipping browser chrome"
fi

# ══════════════════════════════════════════════════════════════════════════════
step "6/7  Wallpaper + SDDM"
# ══════════════════════════════════════════════════════════════════════════════

# ── Wallpaper ──
if (( ! SKIP_WALLPAPER )); then
  WP_SRC="$DOTFILES_DIR/assets/wallpaper.jpg"
  if [[ -f "$WP_SRC" ]]; then
    WP_DIR="$HOME/.local/share/wallpapers"
    WP_DST="$WP_DIR/wallpaper.jpg"
    run mkdir -p "$WP_DIR"
    run cp -f "$WP_SRC" "$WP_DST"
    backup_path "$HOME/.config/background"
    run ln -s "$WP_DST" "$HOME/.config/background"
    log "Wallpaper installed → $WP_DST"
  else
    warn "assets/wallpaper.jpg not found — skipping"
  fi
else
  log "Skipping wallpaper (--no-wallpaper)"
fi

# ── SDDM ──
if (( ! SKIP_SDDM )); then
  ensure_sudo

  THEME_SRC="$DOTFILES_DIR/system/sddm/themes/sddm-astronaut-theme"
  if [[ -d "$THEME_SRC" ]]; then
    log "Installing sddm-astronaut-theme"
    run sudo mkdir -p /usr/share/sddm/themes/sddm-astronaut-theme
    run sudo cp -a "$THEME_SRC/." /usr/share/sddm/themes/sddm-astronaut-theme/
  else
    warn "SDDM theme source not found at $THEME_SRC — skipping theme copy"
  fi

  log "Writing /etc/sddm.conf.d/10-theme.conf"
  if (( DRY_RUN )); then
    log "[dry] Would write Current=sddm-astronaut-theme to /etc/sddm.conf.d/10-theme.conf"
  else
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null <<'CONF'
[Theme]
Current=sddm-astronaut-theme
CONF
  fi

  log "Enabling sddm.service"
  run sudo systemctl enable sddm

else
  log "Skipping SDDM (--no-sddm)"
fi

# ══════════════════════════════════════════════════════════════════════════════
step "7/7  Shell — fish default + Fisher plugins"
# ══════════════════════════════════════════════════════════════════════════════

if command -v fish &>/dev/null; then
  FISH_BIN="$(command -v fish)"

  # Set fish as the default shell
  if [[ "${SHELL:-}" != "$FISH_BIN" ]]; then
    # chsh requires fish to be listed in /etc/shells
    if ! grep -qxF "$FISH_BIN" /etc/shells; then
      log "Adding $FISH_BIN to /etc/shells"
      run sudo tee -a /etc/shells <<<"$FISH_BIN" >/dev/null
    fi
    log "Setting fish as default shell"
    run chsh -s "$FISH_BIN" "$USER"
  else
    log "fish is already the default shell"
  fi

  # Install Fisher and plugins
  if (( ! SKIP_FISHER )); then
    if (( DRY_RUN )); then
      log "[dry] Would install Fisher and fish plugins"
    else
      log "Installing Fisher (fish plugin manager)"
      fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/HEAD/functions/fisher.fish | source && fisher install jorgebucaran/fisher"

      log "Installing fish plugins"
      # franciscolourenco/done — desktop notification when long commands finish
      fish -c "fisher install franciscolourenco/done"
    fi
  else
    log "Skipping Fisher (--no-fisher)"
  fi

else
  warn "fish not found in PATH — skipping shell setup"
  warn "  (Run with --no-packages? Install fish manually and rerun.)"
fi

# ══════════════════════════════════════════════════════════════════════════════
printf "\n${G}══ Done! ══${N}\n"
log "Reboot — SDDM will greet you, Hyprland will load your wallpaper automatically."
log ""
log "First-launch reminders:"
log "  • Open Firefox and Zen once, then rerun setup.sh if browser chrome wasn't applied"
log "  • Run 'uv' and 'pyenv install <version>' once to initialise dev environments"
log "  • Use 'flavours apply <scheme>' anytime to switch colour schemes"

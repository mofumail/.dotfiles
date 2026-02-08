#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
INSTALL_SDDM=1
INSTALL_PACKAGES=1
INSTALL_WALLPAPER=1

usage() {
  cat <<'USAGE'
Usage: setup.sh [--dry-run] [--no-sddm] [--no-packages] [--no-wallpaper]

Options:
  --dry-run       Print actions without making changes
  --no-sddm       Skip SDDM theme/config installation
  --no-packages   Skip package installation
  --no-wallpaper  Skip wallpaper copy + background symlink
  -h, --help      Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-sddm) INSTALL_SDDM=0 ;;
    --no-packages) INSTALL_PACKAGES=0 ;;
    --no-wallpaper) INSTALL_WALLPAPER=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
  shift
  done

log() { echo "[setup] $*"; }
warn() { echo "[setup][warn] $*"; }
die() { echo "[setup][error] $*"; exit 1; }

run() {
  if (( DRY_RUN )); then
    echo "[dry-run] $*"
    return 0
  fi
  "$@"
}

ensure_sudo() {
  if (( DRY_RUN )); then
    log "Would request sudo"
    return 0
  fi
  sudo -v
}

if [[ ${EUID} -eq 0 ]]; then
  die "Do not run this script as root. Run as your normal user."
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID_LIKE:-}" != *arch* && "${ID:-}" != *arch* && "${ID:-}" != *cachyos* ]]; then
    warn "This script is intended for CachyOS/Arch. Detected: ${ID:-unknown}."
  fi
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_REPO_DEFAULT="https://github.com/mofumail/.dotfiles.git"
DOTFILES_DIR=""

if [[ -d "$SCRIPT_DIR/.git" && -f "$SCRIPT_DIR/hypr/hyprland.conf" ]]; then
  DOTFILES_DIR="$SCRIPT_DIR"
else
  DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
  DOTFILES_REPO="${DOTFILES_REPO:-$DOTFILES_REPO_DEFAULT}"
  if ! command -v git >/dev/null 2>&1; then
    if (( INSTALL_PACKAGES )); then
      ensure_sudo
      log "Installing git and base-devel"
      run sudo pacman -S --needed --noconfirm git base-devel
    else
      die "git is required but --no-packages was set. Install git and rerun."
    fi
  fi
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    log "Cloning dotfiles into $DOTFILES_DIR"
    run git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  else
    log "Updating dotfiles in $DOTFILES_DIR"
    run git -C "$DOTFILES_DIR" pull --ff-only
  fi
fi

if (( INSTALL_PACKAGES )); then
  ensure_sudo
  log "Installing system packages"
  run sudo pacman -S --needed --noconfirm base-devel

  if ! command -v paru >/dev/null 2>&1; then
    log "Installing paru (AUR helper)"
    run rm -rf /tmp/paru
    run git clone https://aur.archlinux.org/paru.git /tmp/paru
    run bash -lc "cd /tmp/paru && makepkg -si --noconfirm"
  fi

  PKG_FILE="$DOTFILES_DIR/packages/paru.txt"
  if [[ ! -f "$PKG_FILE" ]]; then
    die "Package list not found: $PKG_FILE"
  fi

  mapfile -t PKGS < <(grep -vE '^\s*(#|$)' "$PKG_FILE")
  if [[ ${#PKGS[@]} -gt 0 ]]; then
    run paru -S --needed --noconfirm "${PKGS[@]}"
  else
    warn "Package list is empty: $PKG_FILE"
  fi
fi

backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local ts dest
    ts="$(date +%Y%m%d-%H%M%S)"
    dest="${path}.bak-${ts}"
    log "Backing up $path -> $dest"
    run mv "$path" "$dest"
  fi
}

link_path() {
  local src="$1" dest="$2"
  backup_path "$dest"
  run mkdir -p "$(dirname "$dest")"
  log "Linking $dest -> $src"
  run ln -s "$src" "$dest"
}

log "Applying configs"
CONFIG_ROOT="$DOTFILES_DIR"
if [[ -d "$DOTFILES_DIR/config" ]]; then
  CONFIG_ROOT="$DOTFILES_DIR/config"
fi

CONFIG_EXCLUDES=(
  ".git"
  ".gitignore"
  "assets"
  "packages"
  "system"
  "setup.sh"
  "README.md"
)

is_excluded() {
  local name="$1"
  local ex
  for ex in "${CONFIG_EXCLUDES[@]}"; do
    if [[ "$name" == "$ex" ]]; then
      return 0
    fi
  done
  return 1
}

shopt -s nullglob
for entry in "$CONFIG_ROOT"/*; do
  name="$(basename "$entry")"
  if is_excluded "$name"; then
    continue
  fi
  if [[ -d "$entry" || -f "$entry" ]]; then
    link_path "$entry" "$HOME/.config/$name"
  fi
done
shopt -u nullglob

if (( INSTALL_WALLPAPER )); then
  WP_SRC="$DOTFILES_DIR/assets/wallpaper.jpg"
  if [[ -f "$WP_SRC" ]]; then
    WP_DIR="$HOME/.local/share/wallpapers"
    WP_DST="$WP_DIR/wallpaper.jpg"
    run mkdir -p "$WP_DIR"
    run cp -f "$WP_SRC" "$WP_DST"
    backup_path "$HOME/.config/background"
    run ln -s "$WP_DST" "$HOME/.config/background"
  else
    warn "Wallpaper file not found: $WP_SRC"
  fi
fi

if (( INSTALL_SDDM )); then
  ensure_sudo
  THEME_SRC="$DOTFILES_DIR/system/sddm/themes/sddm-astronaut-theme"
  if [[ -d "$THEME_SRC" ]]; then
    log "Installing SDDM theme"
    run sudo mkdir -p /usr/share/sddm/themes/sddm-astronaut-theme
    run sudo cp -a "$THEME_SRC/." /usr/share/sddm/themes/sddm-astronaut-theme/
  else
    warn "SDDM theme source not found: $THEME_SRC"
  fi

  log "Configuring SDDM theme"
  if (( DRY_RUN )); then
    echo "[dry-run] Would write /etc/sddm.conf.d/10-theme.conf"
  else
    run sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null <<'CONF'
[Theme]
Current=sddm-astronaut-theme
CONF
  fi
fi

if command -v fish >/dev/null 2>&1; then
  if [[ "${SHELL:-}" != "$(command -v fish)" ]]; then
    log "Setting fish as default shell"
    run chsh -s "$(command -v fish)" "$USER"
  fi
fi

log "Done. If you are in Hyprland, you can set the wallpaper with:"
log "  swww img ~/.local/share/wallpapers/wallpaper.jpg"

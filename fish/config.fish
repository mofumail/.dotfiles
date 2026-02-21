# CachyOS base fish config (present on CachyOS, skipped gracefully elsewhere)
test -f /usr/share/cachyos-fish-config/cachyos-config.fish \
  && source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# starship prompt
command -q starship && starship init fish | source

# uv
test -f "$HOME/.local/bin/env.fish" \
  && source "$HOME/.local/bin/env.fish"

# pyenv
set -gx PYENV_ROOT "$HOME/.pyenv"
fish_add_path "$PYENV_ROOT/bin"
command -q pyenv && pyenv init - --no-rehash fish | source

# rust
test -f "$HOME/.cargo/env.fish" \
  && source "$HOME/.cargo/env.fish"

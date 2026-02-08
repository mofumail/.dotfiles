source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

starship init fish | source

# uv
source "$HOME/.local/share/../bin/env.fish"

# pyenv
set -gx PYENV_ROOT "$HOME/.pyenv"
fish_add_path "$PYENV_ROOT/bin"
pyenv init - --no-rehash fish | source

# rust
source "$HOME/.cargo/env.fish"

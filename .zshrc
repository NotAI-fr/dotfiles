# ==========================
# 1. History Configuration
# ==========================
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Write to history immediately, share across terminals, and ignore duplicates
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# ==========================
# 2. Autocompletions
# ==========================
# Load the advanced completion system
autoload -Uz compinit
compinit

# Allow tab completion to be case-insensitive
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Show a completion menu when multiple matches exist
zstyle ':completion:*' menu yes

# fzf-tab configuration
source /usr/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh

# ==========================
# 3. Plugins
# ==========================
# Source the plugins we installed via pacman
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

alias s='paru -S'
alias fetch='fastfetch'
alias r='paru -R'
alias syu='sudo pacman -Syu'
export DOTFILES_REPO="${DOTFILES_REPO:-$HOME/dotfiles}"
backup() { "$DOTFILES_REPO/backup.sh" "$@"; }

# Syntax highlighting must be sourced after every other plugin and shell setup.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

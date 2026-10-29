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

# IMPORTANT: Syntax highlighting MUST be the very last thing sourced in the file
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

alias s='paru -S'
alias f='fastfetch'






fwg() {
    local dir="$HOME/.config/fastfetch/gifs"
    local state_dir="$HOME/.cache/fastfetch"
    local queue_file="$state_dir/fw-rotation.txt"
    local last_file="$state_dir/last-logo"

    local image_list queue_text shuffled_text
    local previous image item tmp
    local count i swap_idx
    local -a images queue filtered candidates

    # Find all supported character images.
    image_list="$(find "$dir" -maxdepth 1 -type f \
        \( -iname '*.gif' -o -iname '*.png' -o -iname '*.jpg' \
        -o -iname '*.jpeg' -o -iname '*.webp' \) -print | sort)"

    if [[ -z "$image_list" ]]; then
        print -u2 "fwg: No images found in $dir"
        return 1
    fi

    images=("${(@f)image_list}")
    mkdir -p "$state_dir" || return 1

    previous=""
    if [[ -r "$last_file" ]]; then
        previous="$(cat "$last_file")"
    fi

    # Load the remaining images in the current round.
    queue=()
    if [[ -r "$queue_file" ]]; then
        queue_text="$(cat "$queue_file")"
        if [[ -n "$queue_text" ]]; then
            queue=("${(@f)queue_text}")
        fi
    fi

    # Ignore images that have since been deleted or moved.
    filtered=()
    for item in "${queue[@]}"; do
        if [[ -f "$item" && "$item" == "$dir"/* ]]; then
            filtered+=("$item")
        fi
    done
    queue=("${filtered[@]}")

    if (( ${#queue[@]} > 0 )); then
        # Continue the current round.
        image="${queue[1]}"
        count=${#queue[@]}

        : > "$queue_file"
        for (( i = 2; i <= count; i++ )); do
            printf '%s\n' "${queue[$i]}" >> "$queue_file"
        done
    else
        # Everyone has had a turn: shuffle a fresh round.
        shuffled_text="$(printf '%s\n' "${images[@]}" | shuf)"
        candidates=("${(@f)shuffled_text}")
        count=${#candidates[@]}

        # Prevent a repeat across the round boundary.
        if (( count > 1 )) && [[ "${candidates[1]}" == "$previous" ]]; then
            swap_idx=$(( (RANDOM % (count - 1)) + 2 ))
            tmp="${candidates[1]}"
            candidates[1]="${candidates[$swap_idx]}"
            candidates[$swap_idx]="$tmp"
        fi

        image="${candidates[1]}"

        : > "$queue_file"
        for (( i = 2; i <= count; i++ )); do
            printf '%s\n' "${candidates[$i]}" >> "$queue_file"
        done
    fi

    # Remember the selected character for the next invocation.
    printf '%s\n' "$image" > "$last_file"

    fastfetch \
        -c "$HOME/.config/fastfetch/config-wf.jsonc" \
        --kitty "$image" \
        --logo-animation-frame 0
}





alias r='paru -R'
alias ss='paru -Ss'
alias c='clear'
alias cs='rm -f ~/.zsh_history
fc -p'
alias syu='sudo pacman -Syu'
alias backup='~/dotfiles/backup.sh'
export PATH="$HOME/.local/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="/home/nobloat/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

. "$HOME/.cargo/env"

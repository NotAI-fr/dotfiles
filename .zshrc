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
    emulate -L zsh

    local dir="$HOME/.config/fastfetch/gifs"
    local state_dir="$HOME/.cache/fastfetch"

    local state_file="$state_dir/fw-state-v2.txt"
    local lock_file="$state_dir/fw.lock"

    # Files used by the previous version, for migration.
    local old_queue_file="$state_dir/fw-rotation.txt"
    local old_last_file="$state_dir/last-logo"

    local image_list state_text shuffled_text new_images_text
    local section line item image previous=""
    local tmp_file lock_fd tmp
    local i count swap_idx
    local state_ok=0 saw_queue=0 saw_played=0 saw_last=0
    local fresh_round=0 overlap=0

    local -a images state_lines queue played
    local -a filtered_queue filtered_played new_images candidates
    local -a next_queue

    local -A current queued_seen played_seen

    # Find all supported images.
    image_list="$(
        find "$dir" -maxdepth 1 -type f \
            \( -iname '*.gif' -o -iname '*.png' \
            -o -iname '*.jpg' -o -iname '*.jpeg' \
            -o -iname '*.webp' \) -print |
            LC_ALL=C sort
    )"

    if [[ -z "$image_list" ]]; then
        print -u2 "fwg: No images found in $dir"
        return 1
    fi

    images=("${(@f)image_list}")

    mkdir -p -- "$state_dir" || return 1

    # Prevent simultaneous invocations from consuming the same entry.
    exec {lock_fd}> "$lock_file" || {
        print -u2 "fwg: Could not open lock file"
        return 1
    }

    if ! flock -x "$lock_fd"; then
        print -u2 "fwg: Could not acquire rotation lock"
        exec {lock_fd}>&-
        return 1
    fi

    # Load the saved rotation state.
    if [[ -r "$state_file" ]]; then
        state_text="$(<"$state_file")"
        state_lines=("${(@f)state_text}")

        if [[ "${state_lines[1]-}" == "#FWG-STATE-2" ]]; then
            section=""

            for line in "${state_lines[@]}"; do
                case "$line" in
                    "#FWG-STATE-2")
                        ;;
                    "#QUEUE")
                        section="queue"
                        saw_queue=1
                        ;;
                    "#PLAYED")
                        section="played"
                        saw_played=1
                        ;;
                    "#LAST")
                        section="last"
                        saw_last=1
                        ;;
                    *)
                        if [[ "$section" == "queue" && -n "$line" ]]; then
                            queue+=("$line")
                        elif [[ "$section" == "played" && -n "$line" ]]; then
                            played+=("$line")
                        elif [[ "$section" == "last" && -n "$line" && -z "$previous" ]]; then
                            previous="$line"
                        fi
                        ;;
                esac
            done

            if (( saw_queue && saw_played && saw_last )); then
                state_ok=1
            fi
        fi
    fi

    # Start clean if this is the first run or the state is invalid.
    if (( ! state_ok )); then
        queue=()
        played=()
        previous=""

        if [[ -r "$old_last_file" ]]; then
            previous="$(<"$old_last_file")"
        fi

        fresh_round=1
    fi

    # Build a lookup of the images that currently exist.
    for image in "${images[@]}"; do
        current[$image]=1
    done

    # Remove deleted paths and duplicate queue entries.
    filtered_queue=()
    filtered_played=()
    queued_seen=()
    played_seen=()

    if (( state_ok )); then
        for item in "${queue[@]}"; do
            if [[ -n "${current[$item]-}" &&
                  -z "${queued_seen[$item]-}" ]]; then
                filtered_queue+=("$item")
                queued_seen[$item]=1
            fi
        done

        for item in "${played[@]}"; do
            if [[ -n "${current[$item]-}" &&
                  -z "${played_seen[$item]-}" ]]; then
                filtered_played+=("$item")
                played_seen[$item]=1
            fi
        done

        # An image cannot be both played and waiting in the queue.
        for item in "${filtered_queue[@]}"; do
            if [[ -n "${played_seen[$item]-}" ]]; then
                overlap=1
                break
            fi
        done

        if (( overlap )); then
            queue=()
            played=()
            fresh_round=1
        else
            queue=("${filtered_queue[@]}")
            played=("${filtered_played[@]}")
        fi
    fi

    # Recover cleanly if the state contains no usable entries.
    if (( state_ok && ! fresh_round )) &&
       (( ${#queue[@]} == 0 && ${#played[@]} == 0 )); then
        fresh_round=1
    fi

    # Newly added images get a turn before the next full round.
    if (( state_ok && ! fresh_round )); then
        new_images=()

        for item in "${images[@]}"; do
            if [[ -z "${queued_seen[$item]-}" &&
                  -z "${played_seen[$item]-}" ]]; then
                new_images+=("$item")
            fi
        done

        if (( ${#new_images[@]} > 0 )); then
            new_images_text="$(
                printf '%s\n' "${new_images[@]}" | shuf
            )"

            new_images=("${(@f)new_images_text}")
            queue+=("${new_images[@]}")
        fi
    fi

    # Everyone has had a turn: shuffle a fresh round.
    if (( fresh_round || ${#queue[@]} == 0 )); then
        shuffled_text="$(
            printf '%s\n' "${images[@]}" | shuf
        )"

        candidates=("${(@f)shuffled_text}")
        count=${#candidates[@]}

        # Avoid repeating the previous image immediately.
        if (( count > 1 )) &&
           [[ "${candidates[1]}" == "$previous" ]]; then
            swap_idx=$(( (RANDOM % (count - 1)) + 2 ))

            tmp="${candidates[1]}"
            candidates[1]="${candidates[$swap_idx]}"
            candidates[$swap_idx]="$tmp"
        fi

        queue=("${candidates[@]}")
        played=()
    fi

    # Select exactly one image and remove it from the queue.
    image="${queue[1]}"

    next_queue=()
    for (( i = 2; i <= ${#queue[@]}; i++ )); do
        next_queue+=("${queue[$i]}")
    done

    queue=("${next_queue[@]}")
    played+=("$image")

    # Save the entire state using an atomic file replacement.
    # This prevents a half-written queue from being used next time.
    tmp_file="$(mktemp "$state_dir/fw-state.XXXXXX")" || {
        print -u2 "fwg: Could not create temporary state file"
        flock -u "$lock_fd" 2>/dev/null
        exec {lock_fd}>&-
        return 1
    }

    {
        printf '%s\n' "#FWG-STATE-2" "#QUEUE"
        for item in "${queue[@]}"; do
            printf '%s\n' "$item"
        done

        printf '%s\n' "#PLAYED"
        for item in "${played[@]}"; do
            printf '%s\n' "$item"
        done

        printf '%s\n' "#LAST" "$image"
    } > "$tmp_file" || {
        rm -f -- "$tmp_file"
        print -u2 "fwg: Could not write rotation state"
        flock -u "$lock_fd" 2>/dev/null
        exec {lock_fd}>&-
        return 1
    }

    if ! mv -f -- "$tmp_file" "$state_file"; then
        rm -f -- "$tmp_file"
        print -u2 "fwg: Could not save rotation state"
        flock -u "$lock_fd" 2>/dev/null
        exec {lock_fd}>&-
        return 1
    fi

    # The new state file replaces the old cache files.
    rm -f -- "$old_queue_file" "$old_last_file"

    # Release the lock before displaying the image.
    flock -u "$lock_fd" 2>/dev/null
    exec {lock_fd}>&-

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

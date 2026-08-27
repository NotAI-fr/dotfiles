#!/usr/bin/env bash
set -Eeuo pipefail

# Batch-upload images to a Discord webhook.
# Each image is sent as its own Discord message.
#
# Defaults:
#   - Uses the current directory as the wallpaper folder
#   - Recursively scans subfolders
#   - Skips every folder named "lavender-light"
#   - Remembers successfully uploaded files to prevent duplicates
#
# The webhook is never stored in this script.

folder="${WALLPAPER_ROOT:-$PWD}"
delay="1.25"
dry_run=false
resend=false
reset_state=false
caption_paths=false
excludes=("lavender-light")

usage() {
    cat <<'EOF'
Usage:
  upload-wallpapers.sh [options]

Options:
  -f, --folder PATH       Wallpaper folder to scan recursively
  -x, --exclude NAME      Skip a folder with this exact name; repeatable
      --include-lavender  Do not exclude the lavender-light folder
      --caption-paths     Add each image's relative path as its caption
      --delay SECONDS     Delay between successful uploads (default: 1.25)
      --resend            Upload files even if previously recorded
      --reset-state       Forget the upload history before starting
      --dry-run           Show which files would be uploaded
  -h, --help              Show this help

Webhook:
  The script securely prompts for the webhook URL.
  Alternatively, set DISCORD_WEBHOOK_URL for the current shell only.

Examples:
  ./upload-wallpapers.sh --folder "$HOME/dotfiles/Walls"
  ./upload-wallpapers.sh -f ./Walls -x private -x unfinished
  DISCORD_WEBHOOK_URL='...' ./upload-wallpapers.sh -f ./Walls
EOF
}

while (($#)); do
    case "$1" in
        -f|--folder)
            [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
            folder="$2"
            shift 2
            ;;
        -x|--exclude)
            [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
            excludes+=("$2")
            shift 2
            ;;
        --include-lavender)
            excludes=()
            shift
            ;;
        --caption-paths)
            caption_paths=true
            shift
            ;;
        --delay)
            [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
            delay="$2"
            shift 2
            ;;
        --resend)
            resend=true
            shift
            ;;
        --reset-state)
            reset_state=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

for command in curl find sort sha256sum grep; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Required command not found: $command" >&2
        exit 1
    }
done

folder="$(realpath -e "$folder")" || {
    echo "Wallpaper folder does not exist: $folder" >&2
    exit 1
}

[[ -d "$folder" ]] || {
    echo "Not a directory: $folder" >&2
    exit 1
}

state_file="$folder/.discord-wallpaper-uploaded.sha256"

if $reset_state; then
    rm -f -- "$state_file"
    echo "Upload history cleared."
fi

webhook="${DISCORD_WEBHOOK_URL:-}"

if [[ -z "$webhook" && "$dry_run" == false ]]; then
    read -rsp 'Paste Discord webhook URL: ' webhook
    echo
fi

trap 'unset webhook DISCORD_WEBHOOK_URL' EXIT

if [[ "$dry_run" == false ]]; then
    case "$webhook" in
        https://discord.com/api/webhooks/*|https://discordapp.com/api/webhooks/*)
            ;;
        *)
            echo "That does not look like a Discord webhook URL." >&2
            exit 1
            ;;
    esac
fi

is_supported_image() {
    local lower="${1,,}"
    case "$lower" in
        *.png|*.jpg|*.jpeg|*.webp|*.gif|*.bmp)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_excluded() {
    local relative="$1"
    local directory_path="${relative%/*}"

    # A file directly in the root has no directory components.
    [[ "$directory_path" == "$relative" ]] && return 1

    local component excluded
    IFS='/' read -r -a components <<< "$directory_path"

    for component in "${components[@]}"; do
        for excluded in "${excludes[@]}"; do
            [[ "${component,,}" == "${excluded,,}" ]] && return 0
        done
    done

    return 1
}

was_uploaded() {
    local digest="$1"
    [[ -f "$state_file" ]] && grep -qxF -- "$digest" "$state_file"
}

record_upload() {
    local digest="$1"
    printf '%s\n' "$digest" >> "$state_file"
}

total=0
skipped_excluded=0
skipped_uploaded=0
uploaded=0
failed=0

echo "Wallpaper folder: $folder"
if ((${#excludes[@]})); then
    printf 'Excluded folders:'
    printf ' %q' "${excludes[@]}"
    echo
else
    echo "Excluded folders: none"
fi
echo

while IFS= read -r -d '' file; do
    is_supported_image "$file" || continue

    relative="${file#"$folder"/}"
    ((total += 1))

    if is_excluded "$relative"; then
        printf 'SKIP excluded: %s\n' "$relative"
        ((skipped_excluded += 1))
        continue
    fi

    digest="$(sha256sum -- "$file" | awk '{print $1}')"

    if [[ "$resend" == false ]] && was_uploaded "$digest"; then
        printf 'SKIP uploaded: %s\n' "$relative"
        ((skipped_uploaded += 1))
        continue
    fi

    if $dry_run; then
        printf 'WOULD UPLOAD: %s\n' "$relative"
        continue
    fi

    printf 'Uploading: %s ... ' "$relative"

    curl_args=(
        --silent
        --show-error
        --fail-with-body
        --retry 8
        --retry-all-errors
        --retry-delay 2
        --form "files[0]=@$file;filename=$(basename "$file")"
    )

    if $caption_paths; then
        curl_args+=(--form-string "content=$relative")
    fi

    if curl "${curl_args[@]}" "${webhook}?wait=true" >/dev/null; then
        echo "done"
        record_upload "$digest"
        ((uploaded += 1))
        sleep "$delay"
    else
        echo "FAILED" >&2
        ((failed += 1))
    fi
done < <(find "$folder" -type f -print0 | sort -z)

echo
echo "Finished."
echo "Images found:       $total"
echo "Uploaded:           $uploaded"
echo "Already uploaded:   $skipped_uploaded"
echo "Excluded:           $skipped_excluded"
echo "Failed:             $failed"

if $dry_run; then
    echo "Dry run only; nothing was posted."
fi

if ((failed > 0)); then
    exit 1
fi

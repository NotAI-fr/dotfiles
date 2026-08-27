#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/polybar/scripts/psn"
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="${SELF_DIR}/payload"
DEFAULTS_DIR="${APP_DIR}/defaults"
VENV_DIR="${APP_DIR}/venv"
CACHE_DIR="${APP_DIR}/cache"
PSNAWP_VERSION="3.0.3"

bold=$'\033[1m'
reset=$'\033[0m'
green=$'\033[32m'
yellow=$'\033[33m'
red=$'\033[31m'

say() { printf '%s\n' "$*"; }
ok() { printf '%s✓%s %s\n' "${green}" "${reset}" "$*"; }
warn() { printf '%s!%s %s\n' "${yellow}" "${reset}" "$*"; }
die() { printf '%s✗%s %s\n' "${red}" "${reset}" "$*" >&2; exit 1; }

have_payload() {
    [[ -f "${PAYLOAD_DIR}/psn_friends.py" &&
       -f "${PAYLOAD_DIR}/psn-friends" &&
       -f "${PAYLOAD_DIR}/settings.json" ]]
}

installed_defaults_exist() {
    [[ -f "${DEFAULTS_DIR}/psn_friends.py" &&
       -f "${DEFAULTS_DIR}/psn-friends" &&
       -f "${DEFAULTS_DIR}/settings.json" ]]
}

source_defaults_dir() {
    if have_payload; then
        printf '%s' "${PAYLOAD_DIR}"
    elif installed_defaults_exist; then
        printf '%s' "${DEFAULTS_DIR}"
    else
        die "Clean runtime copies are missing. Re-extract the manager ZIP and run setup again."
    fi
}

ensure_base_dirs() {
    mkdir -p "${APP_DIR}" "${DEFAULTS_DIR}" "${CACHE_DIR}" "${APP_DIR}/backups"
}

install_manager_and_defaults() {
    ensure_base_dirs
    local source_dir
    source_dir="$(source_defaults_dir)"

    # Keep the manager permanently in the runtime directory.
    if [[ "${SELF_DIR}" != "${APP_DIR}" ]]; then
        install -m 755 "${BASH_SOURCE[0]}" "${APP_DIR}/setup.sh"
    fi

    install -m 755 "${source_dir}/psn_friends.py" "${DEFAULTS_DIR}/psn_friends.py"
    install -m 755 "${source_dir}/psn-friends" "${DEFAULTS_DIR}/psn-friends"
    install -m 600 "${source_dir}/settings.json" "${DEFAULTS_DIR}/settings.json"
}

timestamp() {
    date +%Y%m%d-%H%M%S
}

backup_current() {
    ensure_base_dirs
    local backup="${APP_DIR}/backups/$(timestamp)"
    mkdir -p "${backup}"

    local copied=0
    for path in psn_friends.py psn-friends setup.sh settings.json npsso auth_tokens.json; do
        if [[ -e "${APP_DIR}/${path}" ]]; then
            cp -a "${APP_DIR}/${path}" "${backup}/${path}"
            copied=1
        fi
    done
    if [[ -d "${CACHE_DIR}" ]]; then
        cp -a "${CACHE_DIR}" "${backup}/cache"
        copied=1
    fi

    if (( copied )); then
        say "Backup: ${backup}"
    else
        rmdir "${backup}" 2>/dev/null || true
    fi
}

stop_workers() {
    # Stop only this module's Python processes. The shell manager is unaffected.
    pkill -f "${APP_DIR}/psn_friends.py" 2>/dev/null || true
    sleep 0.3
    rm -f "${CACHE_DIR}/update.lock" \
          "${CACHE_DIR}/refresh_state.json" \
          "${CACHE_DIR}/status_heartbeat.json"
}

restore_runtime_files() {
    local source_dir
    source_dir="$(source_defaults_dir)"
    install -m 755 "${source_dir}/psn_friends.py" "${APP_DIR}/psn_friends.py"
    install -m 755 "${source_dir}/psn-friends" "${APP_DIR}/psn-friends"
}

merge_settings() {
    local defaults
    defaults="$(source_defaults_dir)/settings.json"
    python - "${defaults}" "${APP_DIR}/settings.json" <<'PY'
import json
import sys
from pathlib import Path

defaults_path = Path(sys.argv[1])
target = Path(sys.argv[2])
defaults = json.loads(defaults_path.read_text(encoding="utf-8"))

try:
    current = json.loads(target.read_text(encoding="utf-8"))
    if not isinstance(current, dict):
        current = {}
except (OSError, json.JSONDecodeError):
    current = {}

# Remove old options that caused week-long friend-list staleness.
current.pop("friends_refresh_days", None)
merged = defaults | current
temporary = target.with_suffix(".json.tmp")
temporary.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")
temporary.replace(target)
target.chmod(0o600)
PY
}

venv_healthy() {
    [[ -x "${VENV_DIR}/bin/python" ]] &&
    "${VENV_DIR}/bin/python" -c \
        'import psnawp_api, importlib.metadata; assert importlib.metadata.version("PSNAWP") == "3.0.3"' \
        >/dev/null 2>&1
}

build_venv() {
    command -v python >/dev/null 2>&1 || die "Python is missing. Install it with: sudo pacman -S python"
    command -v timeout >/dev/null 2>&1 || die "GNU timeout is missing. Install coreutils."

    rm -rf "${VENV_DIR}"
    python -m venv "${VENV_DIR}"
    "${VENV_DIR}/bin/python" -m pip install --upgrade pip
    "${VENV_DIR}/bin/python" -m pip install "PSNAWP==${PSNAWP_VERSION}"
    ok "Private Python environment rebuilt"
}

ensure_venv() {
    if venv_healthy; then
        ok "Private Python environment is healthy"
    else
        warn "Private Python environment is missing or unhealthy"
        build_venv
    fi
}

repair_permissions() {
    chmod 755 "${APP_DIR}/setup.sh" "${APP_DIR}/psn-friends" "${APP_DIR}/psn_friends.py"
    chmod 600 "${APP_DIR}/settings.json"
    [[ -e "${APP_DIR}/npsso" ]] && chmod 600 "${APP_DIR}/npsso"
    [[ -e "${APP_DIR}/auth_tokens.json" ]] && chmod 600 "${APP_DIR}/auth_tokens.json"
}

prompt_token() {
    say
    say "Sign into PlayStation in your browser, then open:"
    say "  https://ca.account.sony.com/api/v1/ssocookie"
    say 'Copy only the value inside "npsso".'
    say
    read -r -s -p "Paste the NPSSO code (hidden): " token
    printf '\n'
    [[ -n "${token}" ]] || die "No NPSSO code was entered."

    umask 077
    printf '%s\n' "${token}" > "${APP_DIR}/npsso"
    chmod 600 "${APP_DIR}/npsso"
    rm -f "${APP_DIR}/auth_tokens.json"
}

test_or_renew_token() {
    if [[ ! -s "${APP_DIR}/npsso" ]]; then
        prompt_token
    fi

    local rc=0
    if "${APP_DIR}/psn-friends" test-auth; then
        ok "Authentication works"
        return
    else
        rc=$?
    fi

    if (( rc != 2 )); then
        die "Sony/PSN could not be reached reliably. Your existing NPSSO was kept; run repair again when the connection is working."
    fi

    warn "The stored NPSSO was specifically rejected by PlayStation"
    prompt_token
    if ! "${APP_DIR}/psn-friends" test-auth; then
        die "The new NPSSO code did not authenticate or Sony could not be reached."
    fi
    ok "New authentication works"
}

clear_transient_state() {
    rm -f "${CACHE_DIR}/update.lock" \
          "${CACHE_DIR}/refresh_state.json" \
          "${CACHE_DIR}/status_heartbeat.json"
}

clear_all_cache() {
    mkdir -p "${CACHE_DIR}"
    find "${CACHE_DIR}" -mindepth 1 -maxdepth 1 -type f -delete
}

verify_fresh_refresh() {
    "${VENV_DIR}/bin/python" - "${CACHE_DIR}/friends.json" "${CACHE_DIR}/presence.json" <<'PY'
import json
import sys
import time
from pathlib import Path

friends_path = Path(sys.argv[1])
presence_path = Path(sys.argv[2])

def load(path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Missing or invalid cache: {path}: {exc}")
    if not isinstance(data, dict):
        raise SystemExit(f"Invalid cache object: {path}")
    return data

friends = load(friends_path)
presence = load(presence_path)
now = time.time()

for label, data in (("friends", friends), ("presence", presence)):
    updated = data.get("updated_at")
    if not isinstance(updated, (int, float)) or now - updated > 120:
        raise SystemExit(f"{label} cache was not freshly rebuilt")

if presence.get("friend_count") != friends.get("friend_count"):
    raise SystemExit("friends and presence cache counts disagree")

print(
    f"Verified fresh cache: {presence.get('online_count', 0)} online / "
    f"{presence.get('friend_count', 0)} friends"
)
PY
}

full_refresh() {
    stop_workers
    clear_transient_state
    say "Rebuilding the current friends list and presence..."
    "${APP_DIR}/psn-friends" refresh
    verify_fresh_refresh
    ok "Fresh friends and presence caches verified"
}

install_or_update() {
    backup_current
    install_manager_and_defaults
    restore_runtime_files
    merge_settings
    ensure_venv
    repair_permissions
    test_or_renew_token
    full_refresh
    say
    "${APP_DIR}/psn-friends" doctor
    say
    ok "PSN Polybar setup is complete"
    say "Manager installed at: ${APP_DIR}/setup.sh"
    say "Restart Polybar with your usual launch/layout script."
}

repair() {
    backup_current
    install_manager_and_defaults
    stop_workers
    restore_runtime_files
    merge_settings
    ensure_venv
    repair_permissions
    test_or_renew_token
    full_refresh
    say
    "${APP_DIR}/psn-friends" doctor
    say
    ok "Repair completed"
}

reinstall() {
    backup_current
    install_manager_and_defaults
    stop_workers

    # Preserve NPSSO and user settings, rebuild everything else.
    rm -rf "${VENV_DIR}"
    rm -f "${APP_DIR}/psn_friends.py" \
          "${APP_DIR}/psn-friends" \
          "${APP_DIR}/auth_tokens.json"
    clear_all_cache

    restore_runtime_files
    merge_settings
    build_venv
    repair_permissions
    test_or_renew_token
    full_refresh
    say
    "${APP_DIR}/psn-friends" doctor
    say
    ok "Reinstallation completed"
}

renew_token() {
    ensure_base_dirs
    [[ -x "${APP_DIR}/psn-friends" ]] || die "Run setup first."
    backup_current
    stop_workers
    prompt_token
    "${APP_DIR}/psn-friends" test-auth || die "Authentication failed."
    full_refresh
    ok "Token renewed and fresh cache verified"
}

doctor() {
    [[ -x "${APP_DIR}/psn-friends" ]] || die "The PSN runtime is not installed."
    "${APP_DIR}/psn-friends" doctor
    say
    say "Recent errors:"
    if [[ -s "${CACHE_DIR}/error.log" ]]; then
        tail -n 20 "${CACHE_DIR}/error.log"
    else
        say "none"
    fi
}

show_logs() {
    mkdir -p "${CACHE_DIR}"
    touch "${CACHE_DIR}/error.log"
    if command -v less >/dev/null 2>&1; then
        less +G "${CACHE_DIR}/error.log"
    else
        tail -n 100 "${CACHE_DIR}/error.log"
    fi
}

reset_cache() {
    [[ -x "${APP_DIR}/psn-friends" ]] || die "Run setup first."
    backup_current
    stop_workers
    clear_all_cache
    test_or_renew_token
    full_refresh
    ok "Cache reset completed"
}

manual_refresh() {
    [[ -x "${APP_DIR}/psn-friends" ]] || die "Run setup first."
    full_refresh
}

print_help() {
    cat <<EOF
${bold}PSN Polybar Manager${reset}

Usage:
  ${APP_DIR}/setup.sh COMMAND

Commands:
  setup        Install or update the managed runtime
  repair       Stop stuck workers, restore scripts, verify venv/token/cache
  reinstall    Rebuild scripts and venv; preserve NPSSO and settings
  token        Enter a fresh NPSSO and rebuild the cache
  refresh      Force and verify a complete friends + presence refresh
  reset-cache  Delete stale caches and rebuild them
  doctor       Show diagnostics and recent errors
  logs         Open the error log
  help         Show this help

Running without a command opens an interactive menu.
EOF
}

interactive_menu() {
    say "${bold}PSN Polybar Manager${reset}"
    say
    say "1) Repair"
    say "2) Force full refresh"
    say "3) Renew NPSSO token"
    say "4) Reinstall runtime"
    say "5) Reset cache"
    say "6) Doctor and logs"
    say "7) Setup/update"
    say "q) Quit"
    say
    read -r -p "Choose: " choice
    case "${choice}" in
        1) repair ;;
        2) manual_refresh ;;
        3) renew_token ;;
        4) reinstall ;;
        5) reset_cache ;;
        6) doctor ;;
        7) install_or_update ;;
        q|Q) exit 0 ;;
        *) die "Unknown choice." ;;
    esac
}

command="${1:-menu}"
case "${command}" in
    setup|install|update) install_or_update ;;
    repair) repair ;;
    reinstall) reinstall ;;
    token|renew-token) renew_token ;;
    refresh) manual_refresh ;;
    reset-cache) reset_cache ;;
    doctor) doctor ;;
    logs) show_logs ;;
    help|-h|--help) print_help ;;
    menu) interactive_menu ;;
    *) print_help; die "Unknown command: ${command}" ;;
esac

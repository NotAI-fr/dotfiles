#!/usr/bin/env python3
"""Reliable PlayStation friend presence for Polybar and Rofi.

Design goals:
- Polybar never waits for the network.
- Old presence is never presented as current indefinitely.
- Newly added/removed friends are periodically discovered.
- The first Polybar run after a long gap (sleep, hibernation, bar restart)
  triggers a complete friends + presence sync.
"""

from __future__ import annotations

import argparse
import fcntl
import importlib.metadata
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable

VERSION = "4.0.0"
ONLINE_MARK = "●"
OFFLINE_MARK = "○"
UNKNOWN_MARK = "?"

APP_DIR = Path(__file__).resolve().parent
CACHE_DIR = APP_DIR / "cache"

TOKEN_FILE = APP_DIR / "npsso"
SETTINGS_FILE = APP_DIR / "settings.json"
AUTH_CACHE = APP_DIR / "auth_tokens.json"

FRIENDS_CACHE = CACHE_DIR / "friends.json"
PRESENCE_CACHE = CACHE_DIR / "presence.json"
REFRESH_STATE = CACHE_DIR / "refresh_state.json"
HEARTBEAT_FILE = CACHE_DIR / "status_heartbeat.json"
LOCK_FILE = CACHE_DIR / "update.lock"
ERROR_LOG = CACHE_DIR / "error.log"

DEFAULT_SETTINGS: dict[str, Any] = {
    # Presence is normally refreshed every three minutes.
    "presence_refresh_seconds": 180,
    # Re-check the actual friends list every six hours so new friends appear.
    "friends_refresh_seconds": 21600,
    # Do not claim an old count is current after ten minutes.
    "stale_after_seconds": 600,
    # A missing Polybar status call for this long is treated as sleep/restart.
    "resume_gap_seconds": 120,
    # Retry delays after consecutive failures: 1m, 2m, then at most 5m.
    "failure_retry_base_seconds": 60,
    "failure_retry_max_seconds": 300,
    "batch_size": 100,
    "show_total_on_bar": False,
}


def ensure_dirs() -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)


def read_json(path: Path, default: Any) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return default


def write_json(path: Path, data: Any, private: bool = False) -> None:
    ensure_dirs()
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    temporary.replace(path)
    if private:
        path.chmod(0o600)


def load_settings() -> dict[str, Any]:
    settings = DEFAULT_SETTINGS.copy()
    loaded = read_json(SETTINGS_FILE, {})
    if isinstance(loaded, dict):
        settings.update(loaded)
    return settings


def load_npsso() -> str:
    try:
        token = TOKEN_FILE.read_text(encoding="utf-8").strip()
    except OSError as exc:
        raise RuntimeError(f"Missing NPSSO file: {TOKEN_FILE}") from exc
    if not token:
        raise RuntimeError(f"NPSSO file is empty: {TOKEN_FILE}")
    return token


def age_seconds(data: dict[str, Any], key: str = "updated_at") -> float:
    timestamp = data.get(key)
    if not isinstance(timestamp, (int, float)):
        return float("inf")
    return max(0.0, time.time() - float(timestamp))


def format_age(seconds: float) -> str:
    if seconds == float("inf"):
        return "never"
    total = int(max(0, seconds))
    if total < 60:
        return f"{total}s ago"
    if total < 3600:
        return f"{total // 60}m ago"
    if total < 86400:
        return f"{total // 3600}h {(total % 3600) // 60}m ago"
    return f"{total // 86400}d {(total % 86400) // 3600}h ago"


def sanitize_log_message(message: str) -> str:
    message = re.sub(r"accountIds=[^&\s)]+", "accountIds=<redacted>", message)
    message = re.sub(r"(https?://[^?\s)]+)\?[^\s)]*", r"\1?<query-redacted>", message)
    return message


def rotate_error_log() -> None:
    try:
        if ERROR_LOG.exists() and ERROR_LOG.stat().st_size > 256 * 1024:
            previous = ERROR_LOG.with_suffix(".log.1")
            previous.unlink(missing_ok=True)
            ERROR_LOG.replace(previous)
    except OSError:
        pass


def log_error(message: str) -> None:
    ensure_dirs()
    rotate_error_log()
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with ERROR_LOG.open("a", encoding="utf-8") as handle:
        handle.write(f"[{timestamp}] {sanitize_log_message(message)}\n")


def chunks(items: list[str], size: int) -> Iterable[list[str]]:
    size = max(1, size)
    for index in range(0, len(items), size):
        yield items[index:index + size]


def load_cached_auth_tokens() -> dict[str, Any]:
    tokens = read_json(AUTH_CACHE, {})
    if not isinstance(tokens, dict):
        return {}
    if not {"access_token", "refresh_token"}.issubset(tokens):
        return {}
    expires_at = tokens.get("refresh_token_expires_at")
    if isinstance(expires_at, (int, float)) and expires_at <= time.time() + 60:
        return {}
    return tokens


def save_auth_tokens(psnawp: Any) -> None:
    tokens = getattr(psnawp.authenticator, "token_response", None)
    if isinstance(tokens, dict) and tokens.get("refresh_token"):
        write_json(AUTH_CACHE, tokens, private=True)


def clear_auth_tokens() -> None:
    AUTH_CACHE.unlink(missing_ok=True)


def create_client(use_cached_auth: bool = True) -> tuple[Any, Any]:
    try:
        from psnawp_api import PSNAWP
    except ImportError as exc:
        raise RuntimeError("PSNAWP is not installed in the PSN virtual environment.") from exc

    psnawp = PSNAWP(load_npsso())
    if use_cached_auth:
        cached = load_cached_auth_tokens()
        if cached:
            psnawp.authenticator.token_response = cached

    client = psnawp.me()
    return psnawp, client


def is_auth_error(exc: Exception) -> bool:
    return type(exc).__name__ in {
        "PSNAWPAuthenticationError",
        "PSNAWPUnauthorizedError",
    }


def current_refresh_state() -> dict[str, Any]:
    state = read_json(REFRESH_STATE, {})
    return state if isinstance(state, dict) else {}


def mark_refresh_running(mode: str) -> None:
    previous = current_refresh_state()
    write_json(
        REFRESH_STATE,
        {
            "status": "running",
            "mode": mode,
            "started_at": time.time(),
            "last_attempt_at": time.time(),
            "last_success_at": previous.get("last_success_at"),
            "consecutive_failures": previous.get("consecutive_failures", 0),
            "next_retry_at": 0,
            "error_type": "",
        },
    )


def mark_refresh_success(mode: str) -> None:
    write_json(
        REFRESH_STATE,
        {
            "status": "success",
            "mode": mode,
            "started_at": 0,
            "last_attempt_at": time.time(),
            "last_success_at": time.time(),
            "consecutive_failures": 0,
            "next_retry_at": 0,
            "error_type": "",
        },
    )


def mark_refresh_failure(mode: str, error_type: str) -> None:
    settings = load_settings()
    previous = current_refresh_state()
    failures = int(previous.get("consecutive_failures", 0)) + 1
    base = max(30, int(settings["failure_retry_base_seconds"]))
    maximum = max(base, int(settings["failure_retry_max_seconds"]))
    delay = min(maximum, base * (2 ** min(failures - 1, 8)))
    write_json(
        REFRESH_STATE,
        {
            "status": "failed",
            "mode": mode,
            "started_at": 0,
            "last_attempt_at": time.time(),
            "last_success_at": previous.get("last_success_at"),
            "consecutive_failures": failures,
            "next_retry_at": time.time() + delay,
            "error_type": error_type,
        },
    )


def rebuild_friends(client: Any) -> list[dict[str, str]]:
    friends: list[dict[str, str]] = []
    for friend in client.friends_list(limit=1000):
        account_id = str(getattr(friend, "account_id", "")).strip()
        online_id = str(getattr(friend, "online_id", account_id)).strip()
        if account_id:
            friends.append({"account_id": account_id, "online_id": online_id})

    friends.sort(key=lambda item: item["online_id"].casefold())
    write_json(
        FRIENDS_CACHE,
        {
            "updated_at": time.time(),
            "friends": friends,
            "friend_count": len(friends),
        },
    )
    return friends


def cached_friends() -> list[dict[str, str]]:
    cache = read_json(FRIENDS_CACHE, {})
    friends = cache.get("friends", []) if isinstance(cache, dict) else []
    return friends if isinstance(friends, list) else []


def parse_presence(
    presence: dict[str, Any],
    online_id: str,
    account_id: str,
) -> dict[str, Any]:
    platform_info = presence.get("primaryPlatformInfo") or {}
    online_status = str(platform_info.get("onlineStatus", "")).lower()
    availability = str(presence.get("availability", "")).lower()
    online = online_status == "online" or availability == "availabletoplay"

    game = ""
    game_status = ""
    game_list = presence.get("gameTitleInfoList") or []
    if game_list and isinstance(game_list[0], dict):
        game = str(game_list[0].get("titleName") or "").strip()
        game_status = str(game_list[0].get("gameStatus") or "").strip()

    return {
        "account_id": account_id,
        "online_id": online_id,
        "online": online,
        "platform": str(platform_info.get("platform") or "").strip(),
        "game": game,
        "game_status": game_status,
        "last_online": platform_info.get("lastOnlineDate") or presence.get("lastAvailableDate") or "",
    }


def fetch_presences(
    client: Any,
    friends: list[dict[str, str]],
    settings: dict[str, Any],
) -> list[dict[str, Any]]:
    account_to_name = {
        str(item.get("account_id", "")): str(item.get("online_id", item.get("account_id", "")))
        for item in friends
        if item.get("account_id")
    }
    account_ids = list(account_to_name)
    entries: list[dict[str, Any]] = []
    seen: set[str] = set()

    batch_size = int(settings.get("batch_size", 100))
    for account_batch in chunks(account_ids, batch_size):
        response = client.get_presences(account_batch)
        for presence in response.get("basicPresences", []):
            account_id = str(presence.get("accountId") or "")
            if not account_id:
                continue
            seen.add(account_id)
            entries.append(
                parse_presence(
                    presence,
                    account_to_name.get(account_id, account_id),
                    account_id,
                )
            )

    for account_id, online_id in account_to_name.items():
        if account_id not in seen:
            entries.append(
                {
                    "account_id": account_id,
                    "online_id": online_id,
                    "online": False,
                    "platform": "",
                    "game": "",
                    "game_status": "",
                    "last_online": "",
                }
            )

    entries.sort(key=lambda item: (not item["online"], item["online_id"].casefold()))
    return entries


def perform_sync(force_friends: bool) -> dict[str, Any]:
    mode = "full" if force_friends else "presence"
    ensure_dirs()

    with LOCK_FILE.open("a+", encoding="utf-8") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return read_json(PRESENCE_CACHE, {})

        mark_refresh_running(mode)
        try:
            try:
                psnawp, client = create_client(use_cached_auth=True)
            except Exception as exc:
                if is_auth_error(exc) and AUTH_CACHE.exists():
                    clear_auth_tokens()
                    psnawp, client = create_client(use_cached_auth=False)
                else:
                    raise

            friends = rebuild_friends(client) if force_friends else cached_friends()
            if not friends:
                friends = rebuild_friends(client)
                mode = "full"

            entries = fetch_presences(client, friends, load_settings())
            save_auth_tokens(psnawp)

            cache = {
                "updated_at": time.time(),
                "friend_list_updated_at": read_json(FRIENDS_CACHE, {}).get("updated_at"),
                "entries": entries,
                "friend_count": len(friends),
                "online_count": sum(1 for item in entries if item.get("online")),
            }
            write_json(PRESENCE_CACHE, cache)
            mark_refresh_success(mode)
            return cache
        except Exception as exc:
            mark_refresh_failure(mode, type(exc).__name__)
            log_error(f"{type(exc).__name__}: {exc}")
            raise


def heartbeat_gap() -> float:
    previous = read_json(HEARTBEAT_FILE, {})
    previous_at = previous.get("last_status_at") if isinstance(previous, dict) else None
    now = time.time()
    write_json(HEARTBEAT_FILE, {"last_status_at": now})
    if not isinstance(previous_at, (int, float)):
        return float("inf")
    return max(0.0, now - float(previous_at))


def friends_sync_due(settings: dict[str, Any]) -> bool:
    return age_seconds(read_json(FRIENDS_CACHE, {})) >= int(settings["friends_refresh_seconds"])


def presence_sync_due(settings: dict[str, Any]) -> bool:
    return age_seconds(read_json(PRESENCE_CACHE, {})) >= int(settings["presence_refresh_seconds"])


def can_retry_now(force: bool = False) -> bool:
    if force:
        return True
    state = current_refresh_state()
    next_retry = state.get("next_retry_at", 0)
    if isinstance(next_retry, (int, float)) and time.time() < next_retry:
        return False

    if state.get("status") == "running":
        started_at = state.get("started_at", 0)
        # The shell wrapper normally records timeouts. This is a final guard
        # for a killed process or machine crash.
        if isinstance(started_at, (int, float)) and time.time() - started_at < 360:
            return False
    return True


def launch_worker(full_sync: bool, force: bool = False) -> None:
    if not can_retry_now(force=force):
        return

    launcher = APP_DIR / "psn-friends"
    command = "full-worker" if full_sync else "presence-worker"
    try:
        # Claim the slot before spawning so simultaneous Polybar modules do not
        # launch duplicate workers.
        mark_refresh_running("full" if full_sync else "presence")
        subprocess.Popen(
            [str(launcher), command],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
    except OSError as exc:
        mark_refresh_failure("full" if full_sync else "presence", type(exc).__name__)
        log_error(f"worker launch: {type(exc).__name__}: {exc}")


def schedule_refresh() -> None:
    settings = load_settings()
    gap = heartbeat_gap()
    resumed_or_restarted = gap >= int(settings["resume_gap_seconds"])

    # After sleep/restart, perform a complete sync so both presence and any new
    # friends are corrected immediately.
    if resumed_or_restarted:
        launch_worker(full_sync=True, force=True)
        return

    if friends_sync_due(settings):
        launch_worker(full_sync=True)
    elif presence_sync_due(settings):
        launch_worker(full_sync=False)


def cached_presence() -> dict[str, Any]:
    cache = read_json(PRESENCE_CACHE, {})
    return cache if isinstance(cache, dict) else {}


def is_presence_stale(cache: dict[str, Any]) -> bool:
    return age_seconds(cache) >= int(load_settings()["stale_after_seconds"])


def print_status(cache: dict[str, Any]) -> None:
    settings = load_settings()
    if not cache or is_presence_stale(cache):
        print(UNKNOWN_MARK, flush=True)
        return

    online = int(cache.get("online_count", 0))
    total = int(cache.get("friend_count", 0))
    print(f"{online}/{total}" if settings.get("show_total_on_bar") else online, flush=True)


def command_status() -> int:
    try:
        cache = cached_presence()
        print_status(cache)
        schedule_refresh()
        return 0
    except Exception as exc:
        log_error(f"status: {type(exc).__name__}: {exc}")
        print(UNKNOWN_MARK, flush=True)
        return 0


def menu_line(item: dict[str, Any], stale: bool) -> str:
    mark = UNKNOWN_MARK if stale else (ONLINE_MARK if item.get("online") else OFFLINE_MARK)
    details: list[str] = []
    if item.get("game"):
        details.append(str(item["game"]))
    if item.get("platform"):
        details.append(str(item["platform"]))
    suffix = f"  —  {' · '.join(details)}" if details else ""
    return f"{mark} {item.get('online_id', 'Unknown')}{suffix}"


def command_menu(show_all: bool) -> int:
    cache = cached_presence()
    stale = is_presence_stale(cache)
    schedule_refresh()

    entries = cache.get("entries", [])
    if not isinstance(entries, list):
        entries = []

    if stale:
        visible = entries if show_all else []
    else:
        visible = entries if show_all else [entry for entry in entries if entry.get("online")]

    lines = [menu_line(item, stale) for item in visible]
    if stale:
        lines.insert(0, "? Status is stale — a fresh PSN sync is running")
    elif not lines:
        lines = ["No friends are currently online"]

    presence_age = format_age(age_seconds(cache))
    friends_age = format_age(age_seconds(read_json(FRIENDS_CACHE, {})))
    message = f"Presence: {presence_age}    Friends list: {friends_age}"

    if not shutil.which("rofi"):
        print(message)
        print("\n".join(lines))
        return 0

    subprocess.run(
        [
            "rofi",
            "-dmenu",
            "-i",
            "-no-custom",
            "-p",
            "All PSN Friends" if show_all else "Online PSN Friends",
            "-mesg",
            message,
        ],
        input="\n".join(lines) + "\n",
        text=True,
        check=False,
    )
    return 0


def command_refresh(full: bool) -> int:
    try:
        cache = perform_sync(force_friends=full)
        print(f"Online: {cache.get('online_count', 0)} / {cache.get('friend_count', 0)}")
        return 0
    except Exception as exc:
        print(f"PSN sync failed: {exc}", file=sys.stderr)
        return 1


def command_worker(full: bool) -> int:
    try:
        perform_sync(force_friends=full)
        return 0
    except Exception:
        return 1


def command_mark_timeout(mode: str) -> int:
    mark_refresh_failure(mode, "Timeout")
    log_error(f"{mode} worker exceeded its hard timeout")
    return 0


def command_test_auth() -> int:
    try:
        psnawp, client = create_client(use_cached_auth=True)
        save_auth_tokens(psnawp)
        print(f"Authenticated as: {client.online_id}")
        return 0
    except Exception as exc:
        log_error(f"test-auth: {type(exc).__name__}: {exc}")
        print(f"Authentication failed: {exc}", file=sys.stderr)
        return 1


def command_doctor() -> int:
    presence = cached_presence()
    friends = read_json(FRIENDS_CACHE, {})
    state = current_refresh_state()
    try:
        package_version = importlib.metadata.version("PSNAWP")
    except importlib.metadata.PackageNotFoundError:
        package_version = "not installed"

    print(f"PSN Polybar script: {VERSION}")
    print(f"PSNAWP: {package_version}")
    print(f"Presence cache: {format_age(age_seconds(presence))}")
    print(f"Friends cache: {format_age(age_seconds(friends))}")
    print(f"Cached friends: {presence.get('friend_count', friends.get('friend_count', 0))}")
    print(f"Cached online: {presence.get('online_count', 0)}")
    print(f"Presence stale: {'yes' if is_presence_stale(presence) else 'no'}")
    print(f"Last refresh state: {state.get('status', 'none')}")
    if state.get("error_type"):
        print(f"Last refresh error: {state['error_type']}")
    print(f"Token cache: {'present' if AUTH_CACHE.exists() else 'missing'}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="PlayStation friend status for Polybar and Rofi")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("status")
    menu = subparsers.add_parser("menu")
    menu.add_argument("--all", action="store_true")

    # Existing middle-click configurations already call `refresh`; it now does
    # the complete friends + presence sync users expect.
    subparsers.add_parser("refresh")
    subparsers.add_parser("refresh-presence")
    subparsers.add_parser("refresh-friends")
    subparsers.add_parser("presence-worker", help=argparse.SUPPRESS)
    subparsers.add_parser("full-worker", help=argparse.SUPPRESS)

    timeout_parser = subparsers.add_parser("mark-timeout", help=argparse.SUPPRESS)
    timeout_parser.add_argument("mode", choices=["presence", "full"])

    subparsers.add_parser("test-auth")
    subparsers.add_parser("doctor")
    return parser


def main() -> int:
    ensure_dirs()
    args = build_parser().parse_args()

    if args.command in (None, "status"):
        return command_status()
    if args.command == "menu":
        return command_menu(args.all)
    if args.command in {"refresh", "refresh-friends"}:
        return command_refresh(full=True)
    if args.command == "refresh-presence":
        return command_refresh(full=False)
    if args.command == "presence-worker":
        return command_worker(full=False)
    if args.command == "full-worker":
        return command_worker(full=True)
    if args.command == "mark-timeout":
        return command_mark_timeout(args.mode)
    if args.command == "test-auth":
        return command_test_auth()
    if args.command == "doctor":
        return command_doctor()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

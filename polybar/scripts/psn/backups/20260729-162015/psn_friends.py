#!/usr/bin/env python3
"""Polybar + Rofi PlayStation friend-presence helper.

Uses the unofficial PSNAWP library. Presence is fetched in batches and cached
to keep API usage conservative.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable

ONLINE_MARK = "●"
OFFLINE_MARK = "○"

APP_DIR = Path(__file__).resolve().parent
CACHE_DIR = APP_DIR / "cache"

TOKEN_FILE = APP_DIR / "npsso"
SETTINGS_FILE = APP_DIR / "settings.json"
FRIENDS_CACHE = CACHE_DIR / "friends.json"
PRESENCE_CACHE = CACHE_DIR / "presence.json"
LOCK_FILE = CACHE_DIR / "update.lock"
ERROR_LOG = CACHE_DIR / "error.log"
AUTH_CACHE = APP_DIR / "auth_tokens.json"
REFRESH_STATE = CACHE_DIR / "refresh_state.json"

DEFAULT_SETTINGS: dict[str, Any] = {
    "presence_refresh_seconds": 300,
    "friends_refresh_days": 7,
    "batch_size": 100,
    "show_total_on_bar": False,
    "failure_retry_seconds": 900,
    "stuck_retry_seconds": 600,
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


def write_json(path: Path, data: Any) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    temporary.replace(path)


def write_private_json(path: Path, data: Any) -> None:
    write_json(path, data)
    path.chmod(0o600)


def load_settings() -> dict[str, Any]:
    settings = DEFAULT_SETTINGS.copy()
    settings.update(read_json(SETTINGS_FILE, {}))
    return settings


def load_npsso() -> str:
    try:
        token = TOKEN_FILE.read_text(encoding="utf-8").strip()
    except OSError as exc:
        raise RuntimeError(
            f"Missing {TOKEN_FILE}. Run the included install.sh or place your NPSSO code there."
        ) from exc

    if not token:
        raise RuntimeError(f"{TOKEN_FILE} is empty.")
    return token


def sanitize_log_message(message: str) -> str:
    # Preserve the useful host/path while removing friend account IDs and
    # other long query-string values from the local log.
    message = re.sub(r"accountIds=[^&\\s)]+", "accountIds=<redacted>", message)
    message = re.sub(
        r"(https?://[^?\\s)]+)\\?[^\\s)]*",
        r"\\1?<query-redacted>",
        message,
    )
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
    safe_message = sanitize_log_message(message)
    with ERROR_LOG.open("a", encoding="utf-8") as handle:
        handle.write(f"[{timestamp}] {safe_message}\n")


def cache_is_fresh(cache: dict[str, Any], max_age_seconds: int) -> bool:
    updated_at = cache.get("updated_at")
    return isinstance(updated_at, (int, float)) and time.time() - updated_at < max_age_seconds


def chunks(items: list[str], size: int) -> Iterable[list[str]]:
    size = max(1, size)
    for index in range(0, len(items), size):
        yield items[index:index + size]


def load_cached_auth_tokens() -> dict[str, Any]:
    token_response = read_json(AUTH_CACHE, {})
    required = {"access_token", "refresh_token"}
    if not isinstance(token_response, dict) or not required.issubset(token_response):
        return {}

    refresh_expires = token_response.get("refresh_token_expires_at")
    if isinstance(refresh_expires, (int, float)) and refresh_expires <= time.time() + 60:
        return {}
    return token_response


def save_auth_tokens(psnawp: Any) -> None:
    token_response = getattr(psnawp.authenticator, "token_response", None)
    if isinstance(token_response, dict) and token_response.get("refresh_token"):
        write_private_json(AUTH_CACHE, token_response)


def clear_auth_tokens() -> None:
    AUTH_CACHE.unlink(missing_ok=True)


def create_client(use_cached_auth: bool = True) -> tuple[Any, Any]:
    try:
        from psnawp_api import PSNAWP
    except ImportError as exc:
        raise RuntimeError("PSNAWP is not installed. Run the included install.sh.") from exc

    psnawp = PSNAWP(load_npsso())
    if use_cached_auth:
        cached_tokens = load_cached_auth_tokens()
        if cached_tokens:
            psnawp.authenticator.token_response = cached_tokens

    client = psnawp.me()
    return psnawp, client


def is_auth_error(exc: Exception) -> bool:
    return type(exc).__name__ in {
        "PSNAWPAuthenticationError",
        "PSNAWPUnauthorizedError",
    }


def mark_refresh_state(status: str, error_type: str = "") -> None:
    write_json(
        REFRESH_STATE,
        {
            "last_attempt_at": time.time(),
            "status": status,
            "error_type": error_type,
        },
    )


def rebuild_friends(client: Any, quiet: bool = False) -> list[dict[str, str]]:
    """Fetch account IDs and PSN online IDs, then cache them.

    PSNAWP currently resolves each friend object individually, so this operation
    is intentionally done only every few days.
    """
    if not quiet:
        print("Refreshing PSN friends list. This first refresh can be slower...", file=sys.stderr)

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
        },
    )
    return friends


def get_friends(client: Any, settings: dict[str, Any], force: bool = False) -> list[dict[str, str]]:
    cached = read_json(FRIENDS_CACHE, {})
    max_age = int(float(settings["friends_refresh_days"]) * 86400)
    friends = cached.get("friends", [])

    if force or not friends or not cache_is_fresh(cached, max_age):
        return rebuild_friends(client, quiet=False)
    return friends


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
        "last_online": (
            platform_info.get("lastOnlineDate")
            or presence.get("lastAvailableDate")
            or ""
        ),
    }


def fetch_presences(
    client: Any,
    friends: list[dict[str, str]],
    settings: dict[str, Any],
) -> list[dict[str, Any]]:
    account_to_name = {
        item["account_id"]: item["online_id"]
        for item in friends
        if item.get("account_id")
    }
    account_ids = list(account_to_name)
    seen: set[str] = set()
    entries: list[dict[str, Any]] = []

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

    # Keep friends returned without a presence record visible as offline.
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


def perform_presence_update(
    settings: dict[str, Any],
    force_friends: bool,
    use_cached_auth: bool,
) -> dict[str, Any]:
    psnawp, client = create_client(use_cached_auth=use_cached_auth)
    friends = get_friends(client, settings, force=force_friends)
    entries = fetch_presences(client, friends, settings)
    save_auth_tokens(psnawp)

    cache = {
        "updated_at": time.time(),
        "entries": entries,
        "friend_count": len(friends),
        "online_count": sum(1 for item in entries if item["online"]),
    }
    write_json(PRESENCE_CACHE, cache)
    return cache


def update_presence(force: bool = False, force_friends: bool = False) -> dict[str, Any]:
    ensure_dirs()
    settings = load_settings()
    old_cache = read_json(PRESENCE_CACHE, {})
    max_age = int(settings["presence_refresh_seconds"])

    if not force and cache_is_fresh(old_cache, max_age):
        return old_cache

    with LOCK_FILE.open("a+", encoding="utf-8") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return old_cache

        old_cache = read_json(PRESENCE_CACHE, {})
        if not force and cache_is_fresh(old_cache, max_age):
            return old_cache

        mark_refresh_state("running")
        try:
            try:
                cache = perform_presence_update(
                    settings,
                    force_friends=force_friends,
                    use_cached_auth=True,
                )
            except Exception as exc:
                # A cached refresh token may have expired or been revoked.
                # Clear it once and fall back to the stored NPSSO code.
                if is_auth_error(exc) and AUTH_CACHE.exists():
                    clear_auth_tokens()
                    cache = perform_presence_update(
                        settings,
                        force_friends=force_friends,
                        use_cached_auth=False,
                    )
                else:
                    raise

            mark_refresh_state("success")
            return cache
        except Exception as exc:
            mark_refresh_state("failed", type(exc).__name__)
            log_error(f"{type(exc).__name__}: {exc}")
            if old_cache.get("entries") is not None:
                return old_cache
            raise


def start_background_refresh() -> None:
    """Start one time-limited refresh without blocking Polybar."""
    launcher = APP_DIR / "psn-friends"
    try:
        subprocess.Popen(
            [str(launcher), "refresh-worker"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
    except OSError as exc:
        log_error(f"background refresh: {type(exc).__name__}: {exc}")


def cached_presence() -> dict[str, Any]:
    return read_json(PRESENCE_CACHE, {})


def schedule_refresh_if_stale(cache: dict[str, Any]) -> None:
    settings = load_settings()
    max_age = int(settings["presence_refresh_seconds"])
    if cache_is_fresh(cache, max_age):
        return

    state = read_json(REFRESH_STATE, {})
    last_attempt = state.get("last_attempt_at", 0)
    age = time.time() - last_attempt if isinstance(last_attempt, (int, float)) else float("inf")
    status = state.get("status")

    if status == "failed" and age < int(settings["failure_retry_seconds"]):
        return
    if status == "running" and age < int(settings["stuck_retry_seconds"]):
        return

    start_background_refresh()


def print_status(cache: dict[str, Any]) -> None:
    settings = load_settings()
    online_count = int(cache.get("online_count", 0))
    friend_count = int(cache.get("friend_count", 0))
    if settings.get("show_total_on_bar"):
        print(f"{online_count}/{friend_count}", flush=True)
    else:
        print(online_count, flush=True)


def command_status() -> int:
    """Return cached output immediately; never make Polybar wait on the network."""
    try:
        cache = cached_presence()
        if cache.get("entries") is None:
            print("!", flush=True)
        else:
            print_status(cache)
        schedule_refresh_if_stale(cache)
        return 0
    except Exception as exc:
        log_error(f"status: {type(exc).__name__}: {exc}")
        print("!", flush=True)
        return 0


def menu_line(item: dict[str, Any]) -> str:
    mark = ONLINE_MARK if item["online"] else OFFLINE_MARK
    details: list[str] = []
    if item.get("game"):
        details.append(str(item["game"]))
    if item.get("platform"):
        details.append(str(item["platform"]))
    suffix = f"  —  {' · '.join(details)}" if details else ""
    return f"{mark} {item['online_id']}{suffix}"


def command_menu(show_all: bool) -> int:
    try:
        cache = cached_presence()
        schedule_refresh_if_stale(cache)
    except Exception as exc:
        log_error(f"menu: {type(exc).__name__}: {exc}")
        subprocess.run(
            ["notify-send", "PlayStation Friends", "Could not read the PSN status cache."],
            check=False,
        )
        return 1

    entries = cache.get("entries", [])
    visible = entries if show_all else [item for item in entries if item.get("online")]
    lines = [menu_line(item) for item in visible]

    if not lines:
        lines = ["No friends are currently online"]

    if not shutil.which("rofi"):
        print("\n".join(lines))
        return 0

    prompt = "All PSN Friends" if show_all else "Online PSN Friends"
    subprocess.run(
        [
            "rofi",
            "-dmenu",
            "-i",
            "-no-custom",
            "-p",
            prompt,
            "-mesg",
            "Left click: online only    Right click: all friends    Middle click: refresh",
        ],
        input="\n".join(lines) + "\n",
        text=True,
        check=False,
    )
    return 0


def command_refresh(force_friends: bool = False) -> int:
    try:
        cache = update_presence(force=True, force_friends=force_friends)
        print(
            f"Online: {cache.get('online_count', 0)} / {cache.get('friend_count', 0)}"
        )
        return 0
    except Exception as exc:
        log_error(f"refresh: {type(exc).__name__}: {exc}")
        print(f"PSN refresh failed: {exc}", file=sys.stderr)
        return 1


def command_refresh_worker() -> int:
    """Quiet background refresh used by the Polybar status command."""
    try:
        update_presence(force=False)
        return 0
    except Exception as exc:
        log_error(f"refresh-worker: {type(exc).__name__}: {exc}")
        return 1


def command_test_auth() -> int:
    try:
        psnawp, client = create_client()
        print(f"Authenticated as: {client.online_id}")
        save_auth_tokens(psnawp)
        return 0
    except Exception as exc:
        log_error(f"test-auth: {type(exc).__name__}: {exc}")
        print(f"Authentication failed: {exc}", file=sys.stderr)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="PlayStation friend status for Polybar and Rofi")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("status", help="Print compact Polybar text")

    menu = subparsers.add_parser("menu", help="Open the Rofi friends list")
    menu.add_argument("--all", action="store_true", help="Include offline friends")

    refresh = subparsers.add_parser("refresh", help="Force a presence refresh")
    refresh.add_argument(
        "--friends",
        action="store_true",
        help="Also rebuild the cached PSN friends list",
    )

    subparsers.add_parser("refresh-friends", help="Rebuild friends and presence caches")
    subparsers.add_parser("refresh-worker", help=argparse.SUPPRESS)
    subparsers.add_parser("test-auth", help="Test the stored NPSSO authentication")
    return parser


def main() -> int:
    ensure_dirs()
    parser = build_parser()
    args = parser.parse_args()

    if args.command in (None, "status"):
        return command_status()
    if args.command == "menu":
        return command_menu(args.all)
    if args.command == "refresh":
        return command_refresh(force_friends=args.friends)
    if args.command == "refresh-friends":
        return command_refresh(force_friends=True)
    if args.command == "refresh-worker":
        return command_refresh_worker()
    if args.command == "test-auth":
        return command_test_auth()

    parser.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

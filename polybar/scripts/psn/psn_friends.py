#!/usr/bin/env python3
"""PlayStation friend presence for Polybar and Rofi.

Runtime location:
    ~/.config/polybar/scripts/psn/

The status command never performs network I/O. It prints the latest verified
cache immediately and starts a separate worker when a refresh is due.
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
from typing import Any, Iterable, TextIO

VERSION = "5.1.0"
ONLINE_MARK = "●"
OFFLINE_MARK = "○"
UNKNOWN_MARK = "?"

APP_DIR = Path(__file__).resolve().parent
CACHE_DIR = APP_DIR / "cache"

TOKEN_FILE = APP_DIR / "npsso"
AUTH_CACHE = APP_DIR / "auth_tokens.json"
SETTINGS_FILE = APP_DIR / "settings.json"

FRIENDS_CACHE = CACHE_DIR / "friends.json"
PRESENCE_CACHE = CACHE_DIR / "presence.json"
REFRESH_STATE = CACHE_DIR / "refresh_state.json"
HEARTBEAT_FILE = CACHE_DIR / "status_heartbeat.json"
UPDATE_LOCK = CACHE_DIR / "update.lock"
ERROR_LOG = CACHE_DIR / "error.log"

DEFAULT_SETTINGS: dict[str, Any] = {
    "presence_refresh_seconds": 180,
    "friends_refresh_seconds": 21600,
    "friend_names_refresh_seconds": 604800,
    "stale_after_seconds": 600,
    "resume_gap_seconds": 120,
    "failure_retry_base_seconds": 60,
    "failure_retry_max_seconds": 300,
    "manual_lock_wait_seconds": 15,
    "batch_size": 100,
    "show_total_on_bar": False,
}


class SyncBusyError(RuntimeError):
    """Raised when another refresh currently owns the update lock."""


def ensure_dirs() -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)


def read_json(path: Path, default: Any) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return default


def write_json(path: Path, data: Any, *, private: bool = False) -> None:
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


def notify(title: str, message: str) -> None:
    if shutil.which("notify-send"):
        subprocess.run(
            ["notify-send", "-a", "PSN Polybar", title, message],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def chunks(items: list[str], size: int) -> Iterable[list[str]]:
    size = max(1, size)
    for index in range(0, len(items), size):
        yield items[index:index + size]


def quarantine_bad_auth_cache() -> None:
    if not AUTH_CACHE.exists():
        return
    invalid = AUTH_CACHE.with_name(
        f"{AUTH_CACHE.name}.invalid-{time.strftime('%Y%m%d-%H%M%S')}"
    )
    try:
        AUTH_CACHE.replace(invalid)
    except OSError:
        AUTH_CACHE.unlink(missing_ok=True)


def load_cached_auth_tokens() -> dict[str, Any]:
    tokens = read_json(AUTH_CACHE, {})
    if not isinstance(tokens, dict):
        if AUTH_CACHE.exists():
            quarantine_bad_auth_cache()
        return {}

    required = ("access_token", "refresh_token")
    if not all(isinstance(tokens.get(key), str) and tokens.get(key) for key in required):
        if AUTH_CACHE.exists():
            quarantine_bad_auth_cache()
        return {}

    expires_at = tokens.get("refresh_token_expires_at")
    if expires_at is not None and not isinstance(expires_at, (int, float)):
        quarantine_bad_auth_cache()
        return {}
    if isinstance(expires_at, (int, float)) and expires_at <= time.time() + 60:
        return {}
    return tokens


def save_auth_tokens(psnawp: Any) -> None:
    tokens = getattr(psnawp.authenticator, "token_response", None)
    if not isinstance(tokens, dict):
        raise RuntimeError(
            "Sony returned a malformed authentication token response."
        )

    required = ("access_token", "refresh_token")
    if not all(isinstance(tokens.get(key), str) and tokens.get(key) for key in required):
        raise RuntimeError(
            "Sony returned an incomplete authentication token response."
        )
    write_json(AUTH_CACHE, tokens, private=True)


def clear_auth_tokens() -> None:
    AUTH_CACHE.unlink(missing_ok=True)


def create_client(*, use_cached_auth: bool = True) -> tuple[Any, Any]:
    try:
        from psnawp_api import PSNAWP
    except ImportError as exc:
        raise RuntimeError("PSNAWP is not installed in the private environment.") from exc

    psnawp = PSNAWP(load_npsso())
    if use_cached_auth:
        cached = load_cached_auth_tokens()
        if cached:
            psnawp.authenticator.token_response = cached
    return psnawp, psnawp.me()


def is_auth_error(exc: Exception) -> bool:
    return type(exc).__name__ in {
        "PSNAWPAuthenticationError",
        "PSNAWPUnauthorizedError",
    }


def is_bad_cached_auth_error(exc: Exception) -> bool:
    text = str(exc)
    return (
        isinstance(exc, AttributeError)
        and "has no attribute 'get'" in text
    ) or "malformed authentication token response" in text.lower()


def create_authenticated_client(*, use_cached_auth: bool = True) -> tuple[Any, Any]:
    return create_client(use_cached_auth=use_cached_auth)


def current_refresh_state() -> dict[str, Any]:
    state = read_json(REFRESH_STATE, {})
    return state if isinstance(state, dict) else {}


def mark_refresh_running(mode: str) -> None:
    previous = current_refresh_state()
    now = time.time()
    write_json(
        REFRESH_STATE,
        {
            "status": "running",
            "mode": mode,
            "pid": os.getpid(),
            "started_at": now,
            "last_attempt_at": now,
            "last_success_at": previous.get("last_success_at"),
            "consecutive_failures": previous.get("consecutive_failures", 0),
            "next_retry_at": 0,
            "error_type": "",
        },
    )


def mark_refresh_success(mode: str) -> None:
    now = time.time()
    write_json(
        REFRESH_STATE,
        {
            "status": "success",
            "mode": mode,
            "pid": 0,
            "started_at": 0,
            "last_attempt_at": now,
            "last_success_at": now,
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
            "pid": 0,
            "started_at": 0,
            "last_attempt_at": time.time(),
            "last_success_at": previous.get("last_success_at"),
            "consecutive_failures": failures,
            "next_retry_at": time.time() + delay,
            "error_type": error_type,
        },
    )


def acquire_update_lock(handle: TextIO, wait_seconds: float) -> None:
    deadline = time.monotonic() + max(0.0, wait_seconds)
    while True:
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return
        except BlockingIOError:
            if time.monotonic() >= deadline:
                raise SyncBusyError("Another PSN refresh is already running.")
            time.sleep(0.25)


def update_lock_is_held() -> bool:
    ensure_dirs()
    with UPDATE_LOCK.open("a+", encoding="utf-8") as handle:
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        return False


def fetch_friend_ids(client: Any) -> list[str]:
    # PSNAWP's public friends_list() resolves every profile separately. The
    # underlying friends endpoint already returns all account IDs in one call,
    # so use the wrapper's authenticated request object directly and resolve
    # only newly added or periodically renamed friends.
    from psnawp_api.utils import API_PATH, BASE_PATH

    response = client.authenticator.get(
        url=f"{BASE_PATH['profile_uri']}{API_PATH['friends_list'].format(account_id='me')}",
        params={"limit": 1000},
    ).json()
    friend_ids = response.get("friends", [])
    if not isinstance(friend_ids, list):
        raise RuntimeError("Sony returned an invalid friends-list response.")
    return [str(account_id) for account_id in friend_ids if str(account_id)]


def rebuild_friends(psnawp: Any, client: Any) -> list[dict[str, str]]:
    settings = load_settings()
    old_cache = read_json(FRIENDS_CACHE, {})
    old_friends = old_cache.get("friends", []) if isinstance(old_cache, dict) else []
    old_names = {
        str(item.get("account_id")): str(item.get("online_id"))
        for item in old_friends
        if isinstance(item, dict) and item.get("account_id") and item.get("online_id")
    }

    friend_ids = fetch_friend_ids(client)
    names_age = age_seconds(old_cache, "names_updated_at")
    refresh_all_names = names_age >= int(settings["friend_names_refresh_seconds"])

    friends: list[dict[str, str]] = []
    name_resolution_errors = 0
    for account_id in friend_ids:
        online_id = "" if refresh_all_names else old_names.get(account_id, "")
        if not online_id:
            try:
                online_id = str(psnawp.user(account_id=account_id).online_id)
            except Exception as exc:
                name_resolution_errors += 1
                online_id = old_names.get(account_id, account_id)
                log_error(
                    f"friend-name {account_id[-4:]}: {type(exc).__name__}: {exc}"
                )
        friends.append({"account_id": account_id, "online_id": online_id})

    friends.sort(key=lambda item: item["online_id"].casefold())
    now = time.time()
    names_updated_at = (
        now
        if refresh_all_names or not old_names
        else old_cache.get("names_updated_at", now)
    )
    write_json(
        FRIENDS_CACHE,
        {
            "updated_at": now,
            "names_updated_at": names_updated_at,
            "friends": friends,
            "friend_count": len(friends),
            "name_resolution_errors": name_resolution_errors,
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
        "online_status": online_status,
        "availability": availability,
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
) -> list[dict[str, Any]]:
    settings = load_settings()
    account_to_name = {
        str(item.get("account_id", "")): str(
            item.get("online_id", item.get("account_id", ""))
        )
        for item in friends
        if item.get("account_id")
    }
    account_ids = list(account_to_name)
    entries: list[dict[str, Any]] = []
    seen: set[str] = set()

    for account_batch in chunks(account_ids, int(settings["batch_size"])):
        response = client.get_presences(account_batch)
        presences = response.get("basicPresences", [])
        if not isinstance(presences, list):
            raise RuntimeError("Sony returned an invalid presence response.")
        for presence in presences:
            if not isinstance(presence, dict):
                continue
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

    # A missing record is treated as unknown/offline in the count, but is kept
    # in the all-friends menu with raw fields for diagnostics.
    for account_id, online_id in account_to_name.items():
        if account_id not in seen:
            entries.append(
                {
                    "account_id": account_id,
                    "online_id": online_id,
                    "online": False,
                    "online_status": "missing",
                    "availability": "missing",
                    "platform": "",
                    "game": "",
                    "game_status": "",
                    "last_online": "",
                }
            )

    entries.sort(key=lambda item: (not item["online"], item["online_id"].casefold()))
    return entries


def perform_sync_attempt(
    *,
    full: bool,
    use_cached_auth: bool,
) -> tuple[dict[str, Any], str]:
    mode = "full" if full else "presence"
    psnawp, client = create_authenticated_client(use_cached_auth=use_cached_auth)
    friends = rebuild_friends(psnawp, client) if full else cached_friends()
    if not friends:
        friends = rebuild_friends(psnawp, client)
        mode = "full"

    entries = fetch_presences(client, friends)
    save_auth_tokens(psnawp)

    now = time.time()
    cache = {
        "updated_at": now,
        "friend_list_updated_at": read_json(FRIENDS_CACHE, {}).get("updated_at"),
        "entries": entries,
        "friend_count": len(friends),
        "online_count": sum(1 for item in entries if item.get("online")),
        "missing_presence_count": sum(
            1 for item in entries if item.get("online_status") == "missing"
        ),
    }
    write_json(PRESENCE_CACHE, cache)
    return cache, mode


def perform_sync(
    *,
    full: bool,
    lock_wait_seconds: float,
) -> dict[str, Any]:
    requested_mode = "full" if full else "presence"
    ensure_dirs()

    with UPDATE_LOCK.open("a+", encoding="utf-8") as lock:
        acquire_update_lock(lock, lock_wait_seconds)
        mark_refresh_running(requested_mode)
        try:
            try:
                cache, completed_mode = perform_sync_attempt(
                    full=full,
                    use_cached_auth=True,
                )
            except Exception as exc:
                # PSNAWP is lazy: authentication errors appear on the first
                # actual request, not while constructing the client object.
                if (is_auth_error(exc) or is_bad_cached_auth_error(exc)) and AUTH_CACHE.exists():
                    clear_auth_tokens()
                    cache, completed_mode = perform_sync_attempt(
                        full=full,
                        use_cached_auth=False,
                    )
                else:
                    raise

            mark_refresh_success(completed_mode)
            return cache
        except Exception as exc:
            mark_refresh_failure(requested_mode, type(exc).__name__)
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
    return age_seconds(read_json(FRIENDS_CACHE, {})) >= int(
        settings["friends_refresh_seconds"]
    )


def presence_sync_due(settings: dict[str, Any]) -> bool:
    return age_seconds(read_json(PRESENCE_CACHE, {})) >= int(
        settings["presence_refresh_seconds"]
    )


def retry_is_allowed() -> bool:
    state = current_refresh_state()
    next_retry = state.get("next_retry_at", 0)
    return not (
        isinstance(next_retry, (int, float))
        and time.time() < float(next_retry)
    )


def launch_worker(*, full: bool, ignore_retry: bool = False) -> None:
    if update_lock_is_held():
        return
    if not ignore_retry and not retry_is_allowed():
        return

    launcher = APP_DIR / "psn-friends"
    command = "full-worker" if full else "presence-worker"
    try:
        subprocess.Popen(
            [str(launcher), command],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
    except OSError as exc:
        mark_refresh_failure("full" if full else "presence", type(exc).__name__)
        log_error(f"worker launch: {type(exc).__name__}: {exc}")


def schedule_refresh() -> None:
    settings = load_settings()
    gap = heartbeat_gap()

    if gap >= int(settings["resume_gap_seconds"]):
        launch_worker(full=True, ignore_retry=True)
        return
    if friends_sync_due(settings):
        launch_worker(full=True)
    elif presence_sync_due(settings):
        launch_worker(full=False)


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
    print(
        f"{online}/{total}" if settings.get("show_total_on_bar") else online,
        flush=True,
    )


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
    mark = UNKNOWN_MARK if stale else (
        ONLINE_MARK if item.get("online") else OFFLINE_MARK
    )
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
        visible = entries if show_all else [
            item for item in entries if item.get("online")
        ]

    lines = [menu_line(item, stale) for item in visible]
    if stale:
        lines.insert(0, "? Cached status is stale — refreshing in the background")
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


def command_refresh(*, full: bool) -> int:
    settings = load_settings()
    try:
        cache = perform_sync(
            full=full,
            lock_wait_seconds=float(settings["manual_lock_wait_seconds"]),
        )
    except SyncBusyError as exc:
        notify("PSN refresh already running", str(exc))
        print(str(exc), file=sys.stderr)
        return 75
    except Exception as exc:
        notify("PSN refresh failed", f"{type(exc).__name__}: {exc}")
        print(f"PSN refresh failed: {exc}", file=sys.stderr)
        return 1

    # Avoid treating the immediate post-install bar launch as a resume gap.
    write_json(HEARTBEAT_FILE, {"last_status_at": time.time()})
    print(
        f"Online: {cache.get('online_count', 0)} / "
        f"{cache.get('friend_count', 0)}"
    )
    notify(
        "PSN friends refreshed",
        f"{cache.get('online_count', 0)} online out of "
        f"{cache.get('friend_count', 0)} friends",
    )
    return 0


def command_worker(*, full: bool) -> int:
    try:
        perform_sync(full=full, lock_wait_seconds=0)
        return 0
    except SyncBusyError:
        return 75
    except Exception:
        return 1


def command_mark_timeout(mode: str) -> int:
    state = current_refresh_state()
    if state.get("status") == "running" and state.get("mode") == mode:
        mark_refresh_failure(mode, "Timeout")
        log_error(f"{mode} worker exceeded its hard timeout")
    return 0


def command_test_auth() -> int:
    try:
        try:
            psnawp, client = create_authenticated_client(use_cached_auth=True)
            online_id = client.online_id
        except Exception as exc:
            if (is_auth_error(exc) or is_bad_cached_auth_error(exc)) and AUTH_CACHE.exists():
                clear_auth_tokens()
                psnawp, client = create_authenticated_client(use_cached_auth=False)
                online_id = client.online_id
            else:
                raise

        save_auth_tokens(psnawp)
        print(f"Authenticated as: {online_id}")
        return 0
    except Exception as exc:
        log_error(f"test-auth: {type(exc).__name__}: {exc}")
        print(f"Authentication failed: {exc}", file=sys.stderr)
        return 2 if is_auth_error(exc) else 1


def command_doctor() -> int:
    presence = cached_presence()
    friends = read_json(FRIENDS_CACHE, {})
    state = current_refresh_state()
    tokens = load_cached_auth_tokens()

    try:
        package_version = importlib.metadata.version("PSNAWP")
    except importlib.metadata.PackageNotFoundError:
        package_version = "not installed"

    refresh_expires = tokens.get("refresh_token_expires_at")
    if isinstance(refresh_expires, (int, float)):
        token_status = f"present, expires in {format_age(max(0, refresh_expires - time.time())).replace(' ago', '')}"
    else:
        token_status = "missing"

    print(f"PSN Polybar script: {VERSION}")
    print(f"PSNAWP: {package_version}")
    print(f"NPSSO file: {'present' if TOKEN_FILE.exists() and TOKEN_FILE.stat().st_size else 'missing'}")
    print(f"Reusable token cache: {token_status}")
    print(f"Presence cache: {format_age(age_seconds(presence))}")
    print(f"Friends cache: {format_age(age_seconds(friends))}")
    print(f"Cached friends: {presence.get('friend_count', friends.get('friend_count', 0))}")
    print(f"Cached online: {presence.get('online_count', 0)}")
    print(f"Missing presence records: {presence.get('missing_presence_count', 0)}")
    print(f"Presence stale: {'yes' if is_presence_stale(presence) else 'no'}")
    print(f"Update lock held: {'yes' if update_lock_is_held() else 'no'}")
    print(f"Last refresh state: {state.get('status', 'none')}")
    if state.get("mode"):
        print(f"Last refresh mode: {state['mode']}")
    if state.get("error_type"):
        print(f"Last refresh error: {state['error_type']}")

    online_entries = [
        item.get("online_id", "Unknown")
        for item in presence.get("entries", [])
        if isinstance(item, dict) and item.get("online")
    ]
    print(
        "Cached online users: "
        + (", ".join(online_entries) if online_entries else "none")
    )
    return 0


def command_debug_presence() -> int:
    cache = cached_presence()
    print(f"Presence cache age: {format_age(age_seconds(cache))}")
    print(f"Online count: {cache.get('online_count', 0)}")
    print()
    for item in cache.get("entries", []):
        if not isinstance(item, dict):
            continue
        account_id = str(item.get("account_id", ""))
        masked = f"…{account_id[-4:]}" if account_id else "unknown"
        print(
            f"{item.get('online_id', 'Unknown'):<24} "
            f"{masked:<8} "
            f"online={str(bool(item.get('online'))):<5} "
            f"status={item.get('online_status', ''):<8} "
            f"availability={item.get('availability', ''):<16} "
            f"platform={item.get('platform', ''):<8} "
            f"game={item.get('game', '')}"
        )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="PlayStation friend status for Polybar and Rofi"
    )
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("status")
    menu = subparsers.add_parser("menu")
    menu.add_argument("--all", action="store_true")

    subparsers.add_parser("refresh")
    subparsers.add_parser("refresh-presence")
    subparsers.add_parser("refresh-friends")
    subparsers.add_parser("presence-worker", help=argparse.SUPPRESS)
    subparsers.add_parser("full-worker", help=argparse.SUPPRESS)

    timeout_parser = subparsers.add_parser("mark-timeout", help=argparse.SUPPRESS)
    timeout_parser.add_argument("mode", choices=["presence", "full"])

    subparsers.add_parser("test-auth")
    subparsers.add_parser("doctor")
    subparsers.add_parser("debug-presence")
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
    if args.command == "debug-presence":
        return command_debug_presence()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

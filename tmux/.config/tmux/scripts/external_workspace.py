#!/usr/bin/env python3

import fcntl
import json
import os
import plistlib
import re
import signal
import shlex
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


HOME = Path.home()
HOME = Path(os.environ.get("TMUX_EXTERNAL_HOME", HOME))
CONFIG_PATH = Path(
    os.environ.get(
        "TMUX_EXTERNAL_CONFIG",
        HOME / ".config/tmux/external-workspaces/storage.json",
    )
)
STATE_PATH = Path(
    os.environ.get(
        "TMUX_EXTERNAL_STATE",
        HOME / ".local/state/tmux/storage-workspace.json",
    )
)
TMUX_SOCKET = os.environ.get("TMUX_EXTERNAL_SOCKET", "")
SHELL_COMMANDS = {"bash", "dash", "fish", "sh", "zsh"}
NOTICE_SCRIPT = Path(__file__).resolve().with_name("tmux_notice.py")
OPERATION_LOCK_PATH = STATE_PATH.with_name("storage-operation.lock")
OPERATION_LOG_PATH = STATE_PATH.with_name("storage-operations.log")
BUSY_LOG_PATH = STATE_PATH.with_name("storage-eject-busy.log")
CODEX_COMPLETION_PROMPT = "Ask Codex to do anything"


def run(
    args: List[str], check: bool = False, capture: bool = True,
    timeout: Optional[float] = None,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            args,
            check=check,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        return subprocess.CompletedProcess(
            args,
            124,
            stdout=error.stdout or "",
            stderr=error.stderr or "command timed out",
        )


def tmux(args: List[str]) -> subprocess.CompletedProcess[str]:
    command = ["tmux"]
    if TMUX_SOCKET:
        command.extend(["-L", TMUX_SOCKET])
    return run([*command, *args], timeout=4.0)


def load_config() -> Dict[str, object]:
    with CONFIG_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def pane_key(window: str, pane_index: int) -> str:
    return f"{window}:{pane_index}"


def default_state(config: Dict[str, object]) -> Dict[str, object]:
    panes = {}
    for entry in config["panes"]:
        key = pane_key(str(entry["window"]), int(entry["pane"]))
        panes[key] = {
            "path": str(entry["path"]),
            "resume": str(entry.get("resume", "")),
        }
    return {"parked": True, "panes": panes}


def load_state(config: Dict[str, object]) -> Dict[str, object]:
    state = default_state(config)
    if STATE_PATH.exists():
        try:
            with STATE_PATH.open(encoding="utf-8") as handle:
                saved = json.load(handle)
            state["parked"] = bool(saved.get("parked", state["parked"]))
            for key, value in saved.get("panes", {}).items():
                if not isinstance(value, dict):
                    continue
                if key in state["panes"]:
                    state["panes"][key]["resume"] = str(value.get("resume", ""))
                    continue
                path = str(value.get("path", ""))
                if path:
                    state["panes"][key] = {
                        "path": path,
                        "resume": str(value.get("resume", "")),
                        "dynamic": True,
                    }
        except (OSError, ValueError, TypeError):
            pass
    for entry in config["panes"]:
        configured_resume = str(entry.get("resume", ""))
        if configured_resume:
            key = pane_key(str(entry["window"]), int(entry["pane"]))
            state["panes"][key]["resume"] = configured_resume
    return state


def save_state(state: Dict[str, object]) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATE_PATH.with_suffix(".tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(state, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    temporary.replace(STATE_PATH)


@contextmanager
def state_lock():
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    lock_path = STATE_PATH.with_suffix(".lock")
    with lock_path.open("a+", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        yield


def audit(action: str, detail: str) -> None:
    try:
        OPERATION_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        with OPERATION_LOG_PATH.open("a", encoding="utf-8") as log_file:
            fcntl.flock(log_file.fileno(), fcntl.LOCK_EX)
            log_file.write(
                f"{timestamp}\tpid={os.getpid()}\t{action}\t{detail}\n"
            )
    except OSError:
        pass


@contextmanager
def operation_lock(action: str):
    OPERATION_LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OPERATION_LOCK_PATH.open("a+", encoding="utf-8") as lock_file:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            yield False
            return
        lock_file.seek(0)
        lock_file.truncate()
        lock_file.write(f"{action}\tpid={os.getpid()}\t{time.time():.3f}\n")
        lock_file.flush()
        audit(action, "started")
        try:
            yield True
        finally:
            audit(action, "finished")
            lock_file.seek(0)
            lock_file.truncate()
            lock_file.flush()
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def operation_in_progress() -> bool:
    OPERATION_LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OPERATION_LOCK_PATH.open("a+", encoding="utf-8") as lock_file:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        return False


def session_for_label(label: str) -> Optional[Tuple[str, str]]:
    result = tmux(["list-sessions", "-F", "#{session_id}\t#{session_name}"])
    if result.returncode != 0:
        return None
    exact = None
    for line in result.stdout.splitlines():
        session_id, name = line.split("\t", 1)
        if name == label:
            exact = (session_id, name)
        if name.endswith(f"-{label}"):
            return session_id, name
    return exact


def list_panes(session_id: str) -> Dict[str, Dict[str, object]]:
    fmt = (
        "#{pane_id}\t#{window_name}\t#{pane_index}\t#{pane_current_command}"
        "\t#{pane_current_path}\t#{pane_pid}"
    )
    result = tmux(["list-panes", "-s", "-t", session_id, "-F", fmt])
    panes = {}
    if result.returncode != 0:
        return panes
    for line in result.stdout.splitlines():
        pane_id, window, index, command, path, pid = line.split("\t", 5)
        key = pane_key(window, int(index))
        panes[key] = {
            "id": pane_id,
            "window": window,
            "index": int(index),
            "command": command,
            "path": path,
            "pid": int(pid),
        }
    return panes


def under_mount(path: str, mount_point: str) -> bool:
    normalized = os.path.realpath(path)
    mount = os.path.realpath(mount_point)
    return normalized == mount or normalized.startswith(f"{mount}{os.sep}")


def same_path(first: str, second: str) -> bool:
    return os.path.realpath(first) == os.path.realpath(second)


def disk_info(identifier: str) -> Dict[str, object]:
    result = run(["diskutil", "info", "-plist", identifier])
    if result.returncode != 0 or not result.stdout:
        return {}
    try:
        value = plistlib.loads(result.stdout.encode("utf-8"))
    except (OSError, plistlib.InvalidFileException, ValueError):
        return {}
    return value if isinstance(value, dict) else {}


def configured_volume_info(config: Dict[str, object]) -> Dict[str, object]:
    expected_uuid = str(config.get("volume_uuid", ""))
    if not expected_uuid:
        return {}
    info = disk_info(expected_uuid)
    if str(info.get("VolumeUUID", "")) != expected_uuid:
        return {}
    return info


def eject_target(config: Dict[str, object]) -> str:
    info = configured_volume_info(config)
    return str(
        info.get("ParentWholeDisk")
        or info.get("DeviceIdentifier")
        or config["mount_point"]
    )


def mounted(config: Dict[str, object]) -> bool:
    mount_point = str(config["mount_point"])
    mount_ready = os.path.ismount(mount_point)
    if os.environ.get("TMUX_EXTERNAL_TEST_MOUNT") == "1":
        mount_ready = os.path.isdir(mount_point)
    if not mount_ready:
        return False
    expected_uuid = str(config.get("volume_uuid", ""))
    if not expected_uuid:
        return True
    return str(disk_info(mount_point).get("VolumeUUID", "")) == expected_uuid


def mount_volume(config: Dict[str, object]) -> Tuple[bool, str]:
    if mounted(config):
        return True, ""
    expected_uuid = str(config.get("volume_uuid", ""))
    if not expected_uuid:
        return False, "volume UUID is not configured"
    info = disk_info(expected_uuid)
    device = str(info.get("DeviceIdentifier", ""))
    if not device:
        return False, "disk is not connected"
    result = run(["diskutil", "mount", device], timeout=20.0)
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        if mounted(config):
            return True, ""
        time.sleep(0.2)
    detail = (result.stderr or result.stdout).strip().splitlines()
    return False, detail[-1] if detail else "diskutil mount failed"


def idle_shell(pane: Dict[str, object]) -> bool:
    if str(pane["command"]) not in SHELL_COMMANDS:
        return False
    result = run(["ps", "-o", "tpgid=", "-p", str(pane["pid"])])
    if result.returncode != 0:
        return False
    foreground = result.stdout.strip()
    return foreground.isdigit() and int(foreground) == int(pane["pid"])


def foreground_pid(pane: Dict[str, object]) -> Optional[int]:
    result = run(["ps", "-o", "tpgid=", "-p", str(pane["pid"])])
    if result.returncode != 0:
        return None
    value = result.stdout.strip()
    return int(value) if value.isdigit() else None


def process_details(pid: int) -> Optional[Tuple[int, str]]:
    result = run(["ps", "-o", "ppid=,comm=", "-p", str(pid)])
    if result.returncode != 0:
        return None
    parts = result.stdout.strip().split(maxsplit=1)
    if not parts or not parts[0].isdigit():
        return None
    executable = Path(parts[1]).name if len(parts) > 1 else ""
    return int(parts[0]), executable


def process_children(pid: int) -> List[int]:
    result = run(["pgrep", "-P", str(pid)])
    if result.returncode not in {0, 1}:
        return []
    return [int(value) for value in result.stdout.split() if value.isdigit()]


def idle_yazi_subshell(pane: Dict[str, object]) -> bool:
    foreground = foreground_pid(pane)
    pane_pid = int(pane["pid"])
    if foreground is None or foreground == pane_pid:
        return False
    details = process_details(foreground)
    if not details or details[1] not in SHELL_COMMANDS or process_children(foreground):
        return False

    current = foreground
    for _ in range(12):
        current_details = process_details(current)
        if not current_details:
            return False
        parent, _ = current_details
        if parent == pane_pid or parent <= 1:
            return False
        parent_details = process_details(parent)
        if not parent_details:
            return False
        if parent_details[1] == "yazi":
            return True
        current = parent
    return False


def cancel_pane_mode(pane_id: str) -> None:
    result = tmux(["display-message", "-p", "-t", pane_id, "#{pane_in_mode}"])
    if result.returncode == 0 and result.stdout.strip() == "1":
        tmux(["send-keys", "-t", pane_id, "-X", "cancel"])
        time.sleep(0.1)


def send_command(pane_id: str, command: str) -> bool:
    cancel_pane_mode(pane_id)
    literal = tmux(["send-keys", "-t", pane_id, "-l", command])
    enter_key = tmux(["send-keys", "-t", pane_id, "Enter"])
    return literal.returncode == 0 and enter_key.returncode == 0


def cd_command(target: str, shell: str) -> str:
    quoted = shlex.quote(target)
    if shell == "fish":
        return f"test -d {quoted}; and cd -- {quoted} 2>/dev/null"
    return f"[ -d {quoted} ] && cd -- {quoted} 2>/dev/null"


def wait_for_command(pane_id: str, old_command: str, timeout: float = 3.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = tmux(["display-message", "-p", "-t", pane_id, "#{pane_current_command}"])
        if result.returncode == 0 and result.stdout.strip() != old_command:
            return True
        time.sleep(0.1)
    return False


def unwind_yazi_subshell(pane: Dict[str, object]) -> bool:
    if not idle_yazi_subshell(pane):
        return False
    pane_id = str(pane["id"])
    old_foreground = foreground_pid(pane)
    if old_foreground is None:
        return False
    cancel_pane_mode(pane_id)
    tmux(["send-keys", "-t", pane_id, "C-c"])
    time.sleep(0.1)
    if not send_command(pane_id, "exit"):
        return False
    # `ya emit quit` can return directly to another zsh, without showing Yazi.
    # Wait for this shell to exit instead of requiring a different command name.
    deadline = time.monotonic() + 3.0
    while time.monotonic() < deadline:
        current = foreground_pid(pane)
        if (
            process_details(old_foreground) is None
            and current is not None
            and current > 1
            and current != old_foreground
        ):
            return True
        time.sleep(0.1)
    return False


def stop_yazi(pane: Dict[str, object]) -> bool:
    pane_id = str(pane["id"])
    cancel_pane_mode(pane_id)
    foreground = foreground_pid(pane)
    if foreground is None or foreground == int(pane["pid"]):
        return False
    process = run(["ps", "-o", "comm=", "-p", str(foreground)])
    executable = Path(process.stdout.strip()).name if process.returncode == 0 else ""
    if executable != "yazi":
        return False
    try:
        os.kill(foreground, signal.SIGTERM)
    except (OSError, ProcessLookupError):
        return wait_for_command(pane_id, "yazi", timeout=0.5)
    return wait_for_command(pane_id, "yazi", timeout=2.5)


def pane_transcript(pane_id: str, lines: int = 48) -> str:
    result = tmux(["capture-pane", "-p", "-t", pane_id, "-S", f"-{lines}"])
    return result.stdout if result.returncode == 0 else ""


def completed_codex_transcript(transcript: str) -> bool:
    """Return true only for Codex's idle prompt at the end of a pane."""
    tail = [line.strip() for line in transcript.splitlines() if line.strip()][-16:]
    for index, line in enumerate(tail):
        if CODEX_COMPLETION_PROMPT not in line:
            continue
        following = "\n".join(tail[index + 1 :])
        return "Working (" not in following and "esc to interrupt" not in following
    return False


def completed_codex_pane(pane: Dict[str, object]) -> Optional[int]:
    """Return the foreground Codex process group when it is stably idle."""
    if Path(str(pane["command"])).name != "codex":
        return None
    foreground = foreground_pid(pane)
    if foreground is None or foreground == int(pane["pid"]):
        return None
    process = run(["ps", "-o", "comm=", "-p", str(foreground)])
    executable = Path(process.stdout.strip()).name if process.returncode == 0 else ""
    if executable != "codex":
        return None
    pane_id = str(pane["id"])
    if not completed_codex_transcript(pane_transcript(pane_id)):
        return None
    # A second stable prompt prevents closing a pane while Codex is transitioning
    # from a completed answer to a newly submitted task.
    time.sleep(0.35)
    return foreground if completed_codex_transcript(pane_transcript(pane_id)) else None


def stop_completed_codex(pane: Dict[str, object]) -> bool:
    """Exit a verified completed Codex CLI without touching active work."""
    foreground = completed_codex_pane(pane)
    if foreground is None:
        return False
    try:
        os.killpg(foreground, signal.SIGINT)
    except (OSError, ProcessLookupError):
        return wait_for_command(str(pane["id"]), "codex", timeout=0.5)
    return wait_for_command(str(pane["id"]), "codex", timeout=3.0)


def wait_for_path(pane_id: str, target: str, timeout: float = 2.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = tmux(["display-message", "-p", "-t", pane_id, "#{pane_current_path}"])
        if result.returncode == 0 and same_path(result.stdout.strip(), target):
            return True
        time.sleep(0.1)
    return False


def notify(message: str, level: str = "info", duration: float = 5.0) -> None:
    if os.environ.get("TMUX_EXTERNAL_SUPPRESS_NOTICES") == "1":
        return
    if os.environ.get("TMUX"):
        run(
            [str(NOTICE_SCRIPT), "show", level, str(duration), message],
            timeout=4.0,
        )
    else:
        print(message)


def clear_busy_log() -> None:
    try:
        BUSY_LOG_PATH.unlink(missing_ok=True)
    except OSError:
        pass


def configured_session(config: Dict[str, object]) -> Optional[Tuple[str, str]]:
    return session_for_label(str(config["session_label"]))


def ensure_session(config: Dict[str, object]) -> Optional[Tuple[str, str]]:
    existing = configured_session(config)
    if existing:
        return existing

    entries = list(config["panes"])
    if not entries:
        return None
    label = str(config["session_label"])
    first_window = str(entries[0]["window"])
    result = tmux([
        "new-session", "-d", "-P", "-F", "#{session_id}",
        "-s", label, "-n", first_window, "-c", str(HOME),
    ])
    if result.returncode != 0:
        return None
    session_id = result.stdout.strip()
    if not session_id:
        return None

    windows: Dict[str, List[Dict[str, object]]] = {}
    for entry in entries:
        windows.setdefault(str(entry["window"]), []).append(entry)

    window_targets: Dict[str, str] = {first_window: f"{session_id}:1"}
    tmux(["set-window-option", "-t", window_targets[first_window], "automatic-rename", "off"])
    for window in list(windows)[1:]:
        created = tmux([
            "new-window", "-d", "-P", "-F", "#{window_index}",
            "-t", session_id, "-n", window, "-c", str(HOME),
        ])
        if created.returncode != 0:
            continue
        target = f"{session_id}:{created.stdout.strip()}"
        window_targets[window] = target
        tmux(["set-window-option", "-t", target, "automatic-rename", "off"])

    for window, window_entries in windows.items():
        target = window_targets.get(window)
        if not target:
            continue
        for _ in range(1, len(window_entries)):
            tmux(["split-window", "-d", "-t", target, "-c", str(HOME)])
        if len(window_entries) > 1:
            tmux(["select-layout", "-t", target, "even-horizontal"])

    tmux(["select-window", "-t", window_targets[first_window]])
    with state_lock():
        state = load_state(config)
        state["parked"] = True
        save_state(state)

    name = tmux(["display-message", "-p", "-t", session_id, "#{session_name}"])
    return session_id, name.stdout.strip() or label


def workspace_has_client(config: Dict[str, object]) -> bool:
    result = tmux(["list-clients", "-F", "#{session_name}"])
    if result.returncode != 0:
        return False
    return any(
        is_workspace_session(config, name)
        for name in result.stdout.splitlines()
    )


def workspace_client_pane_ids(config: Dict[str, object]) -> Set[str]:
    result = tmux(["list-clients", "-F", "#{session_name}\t#{pane_id}"])
    if result.returncode != 0:
        return set()
    pane_ids = set()
    for line in result.stdout.splitlines():
        if "\t" not in line:
            continue
        session_name, pane_id = line.split("\t", 1)
        if pane_id and is_workspace_session(config, session_name):
            pane_ids.add(pane_id)
    return pane_ids


def focus(
    config: Dict[str, object], pane_id: str, allow_operation: bool = False
) -> int:
    if (
        not pane_id
        or (not allow_operation and operation_in_progress())
        or not mounted(config)
    ):
        return 0
    if pane_id not in workspace_client_pane_ids(config):
        return 0
    session = configured_session(config)
    if not session:
        return 0

    with state_lock():
        state = load_state(config)
        panes = list_panes(session[0])
        for key, pane in panes.items():
            if str(pane["id"]) != pane_id:
                continue
            saved = state["panes"].get(key)
            if not saved or saved.get("resume") != "yazi":
                return 0
            if str(pane["command"]) == "yazi":
                return 0
            if not under_mount(str(pane["path"]), str(config["mount_point"])):
                return 0
            if not idle_shell(pane):
                return 0
            old_command = str(pane["command"])
            if not send_command(pane_id, "yazi"):
                return 1
            return 0 if wait_for_command(pane_id, old_command, timeout=2.0) else 1
    return 0


def focus_visible_panes(
    config: Dict[str, object], allow_operation: bool = False
) -> None:
    for pane_id in workspace_client_pane_ids(config):
        focus(config, pane_id, allow_operation=allow_operation)


def enter(
    config: Dict[str, object],
    requested_session: str = "",
    quiet: bool = False,
    announce_ready: bool = False,
    allow_operation: bool = False,
) -> int:
    label = str(config["session_label"])
    if requested_session and requested_session != label and not requested_session.endswith(f"-{label}"):
        return 0
    if not allow_operation and operation_in_progress():
        return 0
    session = configured_session(config)
    if not session:
        return 0
    if not mounted(config):
        if requested_session and not quiet:
            notify(f"{config['name']} offline · reconnect then press C-s I", "warn")
        return 0
    if not workspace_has_client(config):
        return 0

    with state_lock():
        state = load_state(config)
        panes = list_panes(session[0])
        parked = bool(state["parked"])
        restored = []
        busy = []
        for key, saved in state["panes"].items():
            pane = panes.get(key)
            target = str(saved["path"])
            if not pane or not os.path.isdir(target):
                continue
            current_path = str(pane["path"])
            needs_restore = parked or same_path(current_path, str(HOME))
            if not needs_restore or under_mount(current_path, str(config["mount_point"])):
                continue
            if str(pane["command"]) == "yazi":
                saved["resume"] = "yazi"
                if not stop_yazi(pane):
                    busy.append(f"{key.replace(':', '.')}:yazi")
                    continue
                pane = list_panes(session[0]).get(key, pane)
            if not idle_shell(pane):
                busy.append(f"{key.replace(':', '.')}:{pane['command']}")
                continue
            sent = send_command(
                str(pane["id"]), cd_command(target, str(pane["command"]))
            )
            if not sent or not wait_for_path(str(pane["id"]), target):
                busy.append(f"{key.replace(':', '.')}:cd")
                continue
            restored.append(key.replace(":", "."))
        current_panes = list_panes(session[0])
        state["parked"] = not any(
            under_mount(str(pane["path"]), str(config["mount_point"]))
            for pane in current_panes.values()
        )
        save_state(state)

    # Yazi queries the terminal at startup. Starting it in hidden panes can make
    # terminal replies land in another shell, so only resume client-visible panes.
    focus_visible_panes(config, allow_operation=allow_operation)

    if restored and not quiet:
        notify(f"{config['name']} ready · restored {len(restored)} SR panes", "ok")
    elif busy and not quiet:
        notify(f"{config['name']} restore waiting · {', '.join(busy[:3])}", "warn")
    elif announce_ready and not quiet:
        notify(f"{config['name']} ready · SR already active", "ok")
    return 0 if not busy else 1


def park(
    config: Dict[str, object], quiet: bool = False, notify_error: bool = False
) -> int:
    session = configured_session(config)
    if not session:
        with state_lock():
            state = load_state(config)
            state["parked"] = True
            save_state(state)
        if not quiet:
            notify(f"{config['name']} parked · SR session is not running", "ok")
        return 0
    mount_point = str(config["mount_point"])
    configured = {
        pane_key(str(entry["window"]), int(entry["pane"])): entry
        for entry in config["panes"]
    }

    with state_lock():
        state = load_state(config)
        panes = list_panes(session[0])
        busy = []
        parked_count = 0
        for key, pane in panes.items():
            current_path = str(pane["path"])
            if not under_mount(current_path, mount_point):
                continue
            entry = configured.get(key)
            if entry:
                saved = state["panes"][key]
            else:
                saved = state["panes"].setdefault(
                    key,
                    {"path": current_path, "resume": "", "dynamic": True},
                )
                saved["path"] = current_path
                saved["dynamic"] = True
                saved["resume"] = ""

            command = str(pane["command"])
            had_yazi = command == "yazi"
            yazi_cleanup_failed = False
            # A stale pane can contain multiple old `Yazi -> S shell` layers.
            # Unwind every idle layer before parking the underlying shell.
            for _ in range(8):
                if command in SHELL_COMMANDS and idle_yazi_subshell(pane):
                    had_yazi = True
                    if not unwind_yazi_subshell(pane):
                        busy.append(f"{key.replace(':', '.')}:yazi-shell")
                        yazi_cleanup_failed = True
                        break
                    pane = list_panes(session[0]).get(key, pane)
                    command = str(pane["command"])
                    continue
                if command == "yazi":
                    had_yazi = True
                    saved["resume"] = "yazi"
                    if not stop_yazi(pane):
                        busy.append(f"{key.replace(':', '.')}:yazi")
                        yazi_cleanup_failed = True
                        break
                    pane = list_panes(session[0]).get(key, pane)
                    command = str(pane["command"])
                    continue
                break
            else:
                busy.append(f"{key.replace(':', '.')}:nested-yazi")
                yazi_cleanup_failed = True
            if yazi_cleanup_failed:
                continue

            if command == "codex" and bool(config.get("close_completed_codex")):
                if not stop_completed_codex(pane):
                    busy.append(f"{key.replace(':', '.')}:codex")
                    continue
                audit(
                    "eject",
                    f"closed completed Codex pane {key.replace(':', '.')}",
                )
                pane = list_panes(session[0]).get(key, pane)
                command = str(pane["command"])

            if entry and not entry.get("resume"):
                saved["resume"] = ""
            elif not entry and had_yazi:
                saved["resume"] = "yazi"

            current_path = str(pane["path"])
            if under_mount(current_path, mount_point):
                if command not in SHELL_COMMANDS or not idle_shell(pane):
                    busy.append(f"{key.replace(':', '.')}:{command}")
                    continue
                sent = send_command(
                    str(pane["id"]), cd_command(str(HOME), str(pane["command"]))
                )
                if not sent or not wait_for_path(str(pane["id"]), str(HOME)):
                    busy.append(f"{key.replace(':', '.')}:cd")
                    continue
                parked_count += 1

        current_panes = list_panes(session[0])
        state["parked"] = not any(
            under_mount(str(pane["path"]), mount_point)
            for pane in current_panes.values()
        )
        save_state(state)

    if busy:
        BUSY_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        BUSY_LOG_PATH.write_text("\n".join(busy) + "\n", encoding="utf-8")
        if not quiet or notify_error:
            notify(f"{config['name']} still busy · {', '.join(busy[:3])}", "warn")
        return 1
    if not quiet:
        notify(f"{config['name']} parked · released {parked_count} SR panes", "ok")
    return 0


def volume_users(config: Dict[str, object]) -> Tuple[bool, str, str]:
    result = run(
        ["lsof", "-nP", "+f", "--", str(config["mount_point"])],
        timeout=12.0,
    )
    if result.returncode == 0:
        return True, result.stdout.strip(), ""
    if result.returncode == 1 and not result.stderr.strip():
        return True, "", ""
    detail = (result.stderr or result.stdout).strip().splitlines()
    return False, "", detail[-1] if detail else f"lsof exited {result.returncode}"


def lsof_pids(users: str) -> Set[int]:
    pids: Set[int] = set()
    for line in users.splitlines()[1:]:
        parts = line.split()
        if len(parts) > 1 and parts[1].isdigit():
            pids.add(int(parts[1]))
    return pids


def process_table() -> Dict[int, Dict[str, object]]:
    result = run(
        ["ps", "-axo", "pid=,ppid=,pgid=,tty=,comm=,args="], timeout=4.0
    )
    if result.returncode != 0:
        return {}
    processes: Dict[int, Dict[str, object]] = {}
    for line in result.stdout.splitlines():
        parts = line.strip().split(maxsplit=5)
        if (
            len(parts) < 5
            or not parts[0].isdigit()
            or not parts[1].isdigit()
            or not parts[2].isdigit()
        ):
            continue
        processes[int(parts[0])] = {
            "ppid": int(parts[1]),
            "pgid": int(parts[2]),
            "tty": parts[3],
            "command": parts[4],
            "args": parts[5] if len(parts) > 5 else parts[4],
        }
    return processes


def kitty_session_root(
    pid: int, processes: Dict[int, Dict[str, object]]
) -> Optional[int]:
    """Return the Kitty run-shell login ancestor for a process, if any."""
    current = pid
    visited: Set[int] = set()
    while current > 1 and current not in visited:
        visited.add(current)
        process = processes.get(current)
        if not process:
            return None
        args = str(process["args"])
        if "kitty.app/Contents/MacOS/kitten run-shell" in args:
            return current
        current = int(process["ppid"])
    return None


def process_descendants(
    root: int, processes: Dict[int, Dict[str, object]]
) -> List[int]:
    children: Dict[int, List[int]] = {}
    for pid, process in processes.items():
        children.setdefault(int(process["ppid"]), []).append(pid)
    descendants: List[int] = []
    stack = [root]
    while stack:
        current = stack.pop()
        descendants.append(current)
        stack.extend(children.get(current, []))
    return descendants


def command_name(process: Dict[str, object]) -> str:
    return Path(str(process["command"])).name.lstrip("-")


def kitty_session_is_safe_to_close(
    pids: List[int], processes: Dict[int, Dict[str, object]]
) -> Tuple[bool, str]:
    """Allow only disposable terminal sessions to be closed during eject.

    A local iap client is intentionally treated as disposable: its remote tmux
    session survives the local SSH client closing.  Codex, interpreters and any
    unknown foreground command remain a hard stop for automatic eject.
    """
    names = {
        command_name(processes[pid])
        for pid in pids
        if pid in processes
    }
    allowed = {"login", "zsh", "bash", "sh", "fish", "yazi", "tmux", "sleep"}
    if names <= allowed:
        return True, ""
    if names <= allowed | {"ssh"}:
        is_iap = any(
            "/opt/homebrew/bin/iap" in str(processes[pid]["args"])
            for pid in pids
            if pid in processes
        )
        if is_iap:
            return True, ""
    return False, ",".join(sorted(names - allowed)) or "unknown"


def close_disposable_kitty_sessions(config: Dict[str, object]) -> Tuple[int, List[str]]:
    """Close standalone Kitty windows that retain this volume as their cwd.

    tmux panes are parked separately.  Kitty OS windows are not tmux panes, so
    they must be discovered from lsof and closed as terminal sessions.  This
    never closes a Kitty session containing Codex or a local interpreter.
    """
    verified, users, _ = volume_users(config)
    if not verified or not users:
        return 0, []
    processes = process_table()
    roots = {
        root
        for pid in lsof_pids(users)
        if (root := kitty_session_root(pid, processes)) is not None
    }
    closed = 0
    blocked: List[str] = []
    for root in sorted(roots):
        pids = process_descendants(root, processes)
        safe, detail = kitty_session_is_safe_to_close(pids, processes)
        if not safe:
            blocked.append(f"kitty:{detail}")
            continue
        # Signal leaves first, then the Kitty login session.  This matches
        # closing only that OS window rather than quitting the Kitty app.
        for pid in reversed(pids):
            try:
                os.kill(pid, signal.SIGHUP)
            except (OSError, ProcessLookupError):
                pass
        closed += 1
    if closed:
        time.sleep(0.5)
    return closed, blocked


def is_disposable_orphaned_inspection_group(
    pids: List[int], processes: Dict[int, Dict[str, object]]
) -> bool:
    """Recognize an abandoned non-interactive `find | head` inspection group.

    A cancelled Codex tool request can orphan this exact read-only command group.
    It has no terminal and cannot receive user input, so it is safe to end before
    ejecting.  Deliberately narrow matching avoids touching detached computation.
    """
    if not pids:
        return False
    first = processes.get(pids[0])
    if not first:
        return False
    leader = processes.get(int(first["pgid"]))
    if not leader or int(leader["ppid"]) > 1 or str(leader["tty"]) not in {"?", "??"}:
        return False
    if command_name(leader) not in SHELL_COMMANDS:
        return False
    names = {command_name(processes[pid]) for pid in pids if pid in processes}
    if not names <= {"zsh", "bash", "sh", "find", "head"} or "find" not in names:
        return False
    args = str(leader["args"])
    if "find " not in args or "| head -" not in args:
        return False
    return not bool(re.search(r"(^|\s)-(?:delete|exec|execdir|ok|okdir)\b", args))


def close_disposable_orphaned_inspection_jobs(
    config: Dict[str, object]
) -> int:
    """Stop only known abandoned read-only inspection jobs holding this volume."""
    verified, users, _ = volume_users(config)
    if not verified or not users:
        return 0
    processes = process_table()
    groups: Dict[int, List[int]] = {}
    for pid, process in processes.items():
        groups.setdefault(int(process["pgid"]), []).append(pid)
    disposable = set()
    for pid in lsof_pids(users):
        process = processes.get(pid)
        if not process:
            continue
        pgid = int(process["pgid"])
        pids = groups.get(pgid, [])
        if is_disposable_orphaned_inspection_group(pids, processes):
            disposable.add(pgid)
    for pgid in sorted(disposable):
        try:
            os.killpg(pgid, signal.SIGTERM)
        except (OSError, ProcessLookupError):
            pass
    if disposable:
        time.sleep(0.5)
    return len(disposable)


def save_eject_checkpoint(config: Dict[str, object]) -> bool:
    script = HOME / ".config/tmux/scripts/tmux_snapshot.py"
    result = run(
        [str(script), "checkpoint", f"{config['name']}-before-eject", "--quiet"],
        timeout=180.0,
    )
    if result.returncode == 0:
        return True
    detail = (result.stderr or result.stdout).strip().splitlines()
    notify(
        f"{config['name']} snapshot failed · eject cancelled"
        f" · {detail[-1] if detail else 'unknown error'}",
        "error",
    )
    return False


def eject_locked(config: Dict[str, object]) -> int:
    started = time.monotonic()
    if not mounted(config):
        clear_busy_log()
        info = configured_volume_info(config)
        if not info:
            notify(f"{config['name']} already ejected · safe to unplug", "ok", 10.0)
            audit("eject", "already ejected: device not connected")
            return 0
        target = eject_target(config)
        notify(f"{config['name']} unmounted · ejecting {target}", "info", 15.0)
        result = run(["diskutil", "eject", target], timeout=45.0)
        audit(
            "eject",
            f"unmounted diskutil target={target} rc={result.returncode}",
        )
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip().splitlines()
            notify(
                f"{config['name']} eject failed · "
                f"{detail[-1] if detail else 'diskutil error'}",
                "error",
                10.0,
            )
            return result.returncode or 1
        notify(f"{config['name']} ejected · safe to unplug", "ok", 10.0)
        audit("eject", "success from unmounted state")
        return 0
    notify(f"{config['name']} eject · parking SR panes", "info", 15.0)
    audit("eject", "parking SR panes")
    if park(config, quiet=True, notify_error=True) != 0:
        try:
            busy_detail = ", ".join(
                BUSY_LOG_PATH.read_text(encoding="utf-8").splitlines()
            )
        except OSError:
            busy_detail = "unknown"
        audit("eject", f"cancelled: SR pane busy ({busy_detail})")
        return 1
    notify(f"{config['name']} eject · saving checkpoint", "info", 125.0)
    audit("eject", "saving checkpoint")
    if not save_eject_checkpoint(config):
        audit("eject", "cancelled: checkpoint failed")
        return 1
    closed_kitty, blocked_kitty = close_disposable_kitty_sessions(config)
    if closed_kitty:
        notify(
            f"{config['name']} eject · closed {closed_kitty} Kitty window(s)",
            "info",
            10.0,
        )
        audit("eject", f"closed disposable Kitty windows={closed_kitty}")
    if blocked_kitty:
        audit("eject", f"kept active Kitty windows={','.join(blocked_kitty)}")
    closed_orphans = close_disposable_orphaned_inspection_jobs(config)
    if closed_orphans:
        notify(
            f"{config['name']} eject · closed {closed_orphans} orphaned scan(s)",
            "info",
            10.0,
        )
        audit("eject", f"closed disposable orphaned scans={closed_orphans}")
    notify(f"{config['name']} eject · checking open files", "info", 15.0)
    check_started = time.monotonic()
    verified, users, detail = volume_users(config)
    audit(
        "eject",
        f"lsof verified={verified} users={bool(users)} "
        f"elapsed={time.monotonic() - check_started:.1f}s detail={detail or '-'}",
    )
    if not verified:
        BUSY_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        BUSY_LOG_PATH.write_text(
            f"open-file check failed: {detail}\n", encoding="utf-8"
        )
        notify(
            f"{config['name']} check failed · eject cancelled · {detail}",
            "error",
            10.0,
        )
        return 1
    if users:
        BUSY_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        BUSY_LOG_PATH.write_text(f"{users}\n", encoding="utf-8")
        processes = []
        for line in users.splitlines()[1:]:
            command = line.split(maxsplit=1)[0] if line.split() else ""
            if command and command not in processes:
                processes.append(command)
        summary = ", ".join(processes[:3]) or "other apps"
        if not os.environ.get("TMUX"):
            print(users, file=sys.stderr)
        notify(
            f"{config['name']} busy · {summary} · eject cancelled",
            "warn",
            10.0,
        )
        audit("eject", f"cancelled: volume busy ({summary})")
        return 1
    clear_busy_log()
    notify(f"{config['name']} eject · releasing disk", "info", 50.0)
    disk_started = time.monotonic()
    target = eject_target(config)
    result = run(["diskutil", "eject", target], timeout=45.0)
    audit(
        "eject",
        f"diskutil target={target} rc={result.returncode} "
        f"elapsed={time.monotonic() - disk_started:.1f}s",
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        notify(
            f"{config['name']} eject failed · {detail[-1] if detail else 'diskutil error'}",
            "error",
            10.0,
        )
        return result.returncode or 1
    elapsed = time.monotonic() - started
    notify(
        f"{config['name']} ejected · SR paths saved · {elapsed:.0f}s", "ok", 10.0
    )
    audit("eject", f"success elapsed={elapsed:.1f}s")
    return 0


def eject(config: Dict[str, object]) -> int:
    with operation_lock("eject") as acquired:
        if not acquired:
            notify(
                f"{config['name']} operation already running · wait for final result",
                "warn",
                10.0,
            )
            audit("eject", "duplicate request ignored")
            return 1
        return eject_locked(config)


def workspace_access_error(mount_point: str) -> str:
    """Check access from the tmux server, which can have different macOS rights."""
    with tempfile.TemporaryDirectory(prefix="tmux-volume-access-") as directory:
        error_path = Path(directory) / "error"
        status_path = Path(directory) / "status"
        command = (
            f"/bin/ls -A {shlex.quote(mount_point)} >/dev/null "
            f"2>{shlex.quote(str(error_path))}; "
            f"printf '%s' \"$?\" >{shlex.quote(str(status_path))}"
        )
        result = tmux(["run-shell", command])
        if result.returncode != 0:
            return (result.stderr or result.stdout).strip() or "access check failed"
        if not status_path.exists():
            return "access check did not complete"
        if status_path.read_text(encoding="utf-8").strip() == "0":
            return ""
        return error_path.read_text(encoding="utf-8").strip() or "volume unreadable"


def restore_locked(config: Dict[str, object], client_tty: str = "") -> int:
    notify(f"{config['name']} restore · checking storage and SR", "info")
    if not mounted(config):
        ready, detail = mount_volume(config)
        if not ready:
            notify(f"{config['name']} offline · {detail}", "warn")
            return 1
        notify(f"{config['name']} mounted · restoring SR", "info")

    access_error = workspace_access_error(str(config["mount_point"]))
    if access_error:
        audit("restore", f"volume access failed: {access_error}")
        if (
            "Operation not permitted" in access_error
            or "Permission denied" in access_error
        ):
            detail = "disk access denied · check macOS terminal permissions"
        else:
            detail = access_error.splitlines()[-1][:160]
        notify(f"{config['name']} restore failed · {detail}", "error", 10.0)
        print(access_error, file=sys.stderr)
        return 1

    session = ensure_session(config)
    if not session:
        notify(f"{config['name']} restore failed · could not create SR session", "error")
        return 1

    command = ["switch-client"]
    if client_tty:
        command.extend(["-c", client_tty])
    command.extend(["-t", session[0]])
    switched = tmux(command)
    if switched.returncode != 0:
        detail = (switched.stderr or switched.stdout).strip()
        notify(f"{config['name']} ready · switch to {session[1]} to restore paths", "ok")
        return 0 if not detail else 1
    time.sleep(0.2)
    return enter(
        config,
        session[1],
        announce_ready=True,
        allow_operation=True,
    )


def restore(config: Dict[str, object], client_tty: str = "") -> int:
    with operation_lock("restore") as acquired:
        if not acquired:
            notify(
                f"{config['name']} operation already running · wait for final result",
                "warn",
                10.0,
            )
            audit("restore", "duplicate request ignored")
            return 1
        return restore_locked(config, client_tty)


def status(config: Dict[str, object]) -> int:
    state = load_state(config)
    session = configured_session(config)
    if not session and not state["parked"]:
        state["parked"] = True
        save_state(state)
    print(f"mounted={mounted(config)} parked={state['parked']} session={session[1] if session else '-'}")
    if session:
        panes = list_panes(session[0])
        for key, saved in state["panes"].items():
            pane = panes.get(key, {})
            print(
                f"{key}\t{pane.get('command', '-')}\t{pane.get('path', '-')}"
                f"\t=>\t{saved['path']}\t{saved.get('resume', '')}"
            )
    return 0


def is_workspace_session(config: Dict[str, object], name: str) -> bool:
    label = str(config["session_label"])
    return name == label or name.endswith(f"-{label}")


def switch(config: Dict[str, object], current: str) -> int:
    if is_workspace_session(config, current):
        enter(config, current, quiet=False)
    return 0


def leave(config: Dict[str, object]) -> int:
    # Detaching or switching sessions must not interrupt background SR work.
    # Releasing storage is an explicit operation through C-s U / eject.
    return 0


def main(argv: List[str]) -> int:
    if len(argv) < 2 or argv[1] not in {
        "eject", "enter", "focus", "leave", "park", "restore", "status", "switch"
    }:
        print(
            f"usage: {argv[0]} eject|enter|focus|leave|park|restore|status|switch [target ...]",
            file=sys.stderr,
        )
        return 2
    config = load_config()
    command = argv[1]
    if command == "enter":
        quiet = len(argv) > 3 and argv[3] == "quiet"
        result = enter(config, argv[2] if len(argv) > 2 else "", quiet=quiet)
        return 0 if quiet else result
    if command == "park":
        return park(config)
    if command == "eject":
        return eject(config)
    if command == "restore":
        return restore(config, argv[2] if len(argv) > 2 else "")
    if command == "focus":
        return focus(config, argv[2] if len(argv) > 2 else "")
    if command == "switch" and len(argv) >= 3:
        return switch(config, argv[2])
    if command == "switch":
        return switch(config, "")
    if command == "leave":
        return leave(config)
    return status(config)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

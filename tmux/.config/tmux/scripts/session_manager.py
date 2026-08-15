#!/usr/bin/env python3

import fcntl
import os
import re
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from typing import Dict, List


def run_tmux(args: List[str], check: bool = True, capture: bool = False) -> str:
    result = subprocess.run(
        ["tmux", *args],
        check=check,
        stdout=subprocess.PIPE if capture else None,
        text=capture,
    )
    return result.stdout.rstrip("\n") if capture else ""


def list_sessions() -> List[Dict[str, object]]:
    output = run_tmux(
        ["list-sessions", "-F", "#{session_id}\t#{session_name}\t#{session_created}"],
        check=False,
        capture=True,
    )
    sessions: List[Dict[str, object]] = []
    for line in output.splitlines():
        session_id, name, created = line.split("\t")
        match = re.match(r"^(\d+)-(.*)$", name)
        temporary = re.match(r"^__tmux_order_(\d+)_\d+__(.*)$", name)
        sessions.append(
            {
                "id": session_id,
                "name": name,
                "created": int(created),
                "index": (
                    int(match.group(1))
                    if match
                    else int(temporary.group(1)) if temporary else None
                ),
                "label": (
                    match.group(2)
                    if match
                    else temporary.group(2) if temporary else name
                ),
            }
        )
    sessions.sort(
        key=lambda entry: (
            0 if entry["index"] is not None else 1,
            entry["index"] if entry["index"] is not None else entry["created"],
        )
    )
    return sessions


def label(value: object) -> str:
    clean = str(value).strip()
    return clean or "session"


@contextmanager
def manager_lock():
    server_pid = run_tmux(
        ["display-message", "-p", "#{pid}"], check=False, capture=True
    ) or "unknown"
    lock_path = os.path.join(
        tempfile.gettempdir(), f"tmux-session-manager-{server_pid}.lock"
    )
    with open(lock_path, "a+", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        yield


def apply_order(sessions: List[Dict[str, object]]) -> None:
    # Temporary unique names prevent collisions when equal labels trade positions.
    for position, session in enumerate(sessions, start=1):
        temporary_name = (
            f"__tmux_order_{position}_{session['created']}__{label(session['label'])}"
        )
        run_tmux(
            ["rename-session", "-t", str(session["id"]), temporary_name],
            check=False,
        )
    for position, session in enumerate(sessions, start=1):
        run_tmux(
            ["rename-session", "-t", str(session["id"]), f"{position}-{label(session['label'])}"],
            check=False,
        )


def current_session_id(target_pane: str = "") -> str:
    args = ["display-message", "-p"]
    if target_pane:
        args.extend(["-t", target_pane])
    args.append("#{session_id}")
    return run_tmux(args, check=False, capture=True)


def command_switch(index_text: str, target_client: str = "") -> None:
    try:
        index = int(index_text)
    except ValueError:
        return
    sessions = list_sessions()
    if 1 <= index <= len(sessions):
        args = ["switch-client"]
        if target_client:
            args.extend(["-c", target_client])
        args.extend(["-t", str(sessions[index - 1]["id"])])
        run_tmux(args, check=False)
        refresh_args = ["refresh-client"]
        if target_client:
            refresh_args.extend(["-t", target_client])
        refresh_args.append("-S")
        run_tmux(refresh_args, check=False)


def command_rename(new_label: str, target_pane: str = "") -> None:
    session_id = current_session_id(target_pane)
    sessions = list_sessions()
    for session in sessions:
        if session["id"] == session_id:
            session["label"] = label(new_label)
            apply_order(sessions)
            return


def command_move(direction: str, target_pane: str = "") -> None:
    sessions = list_sessions()
    session_id = current_session_id(target_pane)
    current = next(
        (position for position, session in enumerate(sessions) if session["id"] == session_id),
        None,
    )
    if current is None:
        return
    target = current - 1 if direction == "left" else current + 1
    if 0 <= target < len(sessions):
        sessions[current], sessions[target] = sessions[target], sessions[current]
        apply_order(sessions)


def main(argv: List[str]) -> None:
    if len(argv) < 2:
        return
    command = argv[1]
    with manager_lock():
        if command == "ensure":
            apply_order(list_sessions())
        elif command == "switch" and len(argv) >= 3:
            command_switch(argv[2], argv[3] if len(argv) >= 4 else "")
        elif command == "rename" and len(argv) >= 3:
            command_rename(argv[2], argv[3] if len(argv) >= 4 else "")
        elif command == "move" and len(argv) >= 3 and argv[2] in {"left", "right"}:
            command_move(argv[2], argv[3] if len(argv) >= 4 else "")


if __name__ == "__main__":
    main(sys.argv)

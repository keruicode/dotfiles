#!/usr/bin/env python3
"""Safely park and eject or restore every registered external tmux workspace.

Each per-volume operation is delegated to ``external_workspace.py``.  That
script saves a tmux-resurrect checkpoint, exits idle Yazi children, moves only
idle shell panes to the home directory, runs an ``lsof`` check, then uses the
ordinary ``diskutil eject`` command.  A busy volume is reported and skipped;
this wrapper never force-unmounts a disk or kills an arbitrary process.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_DIR = SCRIPT_DIR.parent / "external-workspaces"
WORKSPACES = ("storage.json", "linux.json", "tutu.json", "usb.json")
NOTICE_SCRIPT = SCRIPT_DIR / "tmux_notice.py"


def notify(level: str, message: str, duration: float = 10.0) -> None:
    subprocess.run(
        [sys.executable, str(NOTICE_SCRIPT), "show", level, str(duration), message],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def run_workspace(action: str, config_path: Path) -> int:
    env = os.environ.copy()
    name = config_path.stem
    env["TMUX_EXTERNAL_CONFIG"] = str(config_path)
    env["TMUX_EXTERNAL_STATE"] = str(
        Path.home() / ".local/state/tmux" / f"{name}-workspace.json"
    )
    env["TMUX_EXTERNAL_SUPPRESS_NOTICES"] = "1"
    result = subprocess.run(
        [sys.executable, str(SCRIPT_DIR / "external_workspace.py"), action],
        env=env,
        check=False,
    )
    return result.returncode


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in {"eject", "restore"}:
        print(f"usage: {argv[0]} eject|restore", file=sys.stderr)
        return 2

    action = argv[1]
    failed = []
    completed = []
    for filename in WORKSPACES:
        config_path = WORKSPACE_DIR / filename
        if not config_path.is_file():
            failed.append(filename)
            continue
        name = config_path.stem
        if run_workspace(action, config_path) != 0:
            failed.append(name)
        else:
            completed.append(name)

    if failed:
        message = f"external {action} incomplete · {', '.join(failed)} not completed"
        notify("warn", message, 12.0)
        print(message, file=sys.stderr)
        return 1

    message = f"external {action} complete · {', '.join(completed)}"
    notify("ok", message, 8.0)
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

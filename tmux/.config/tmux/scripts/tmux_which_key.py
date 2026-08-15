#!/usr/bin/env python3

import os
import select
import shutil
import subprocess
import sys
import termios
import time
import tty
from pathlib import Path
from typing import List, Optional


RESET = "\033[0m"
CYAN = "\033[38;2;136;229;242m"
PINK = "\033[38;2;255;107;129m"
GOLD = "\033[38;2;255;210;125m"
TEXT = "\033[38;2;248;248;242m"
MUTED = "\033[38;2;154;160;180m"
BOLD = "\033[1m"


ROWS = [
    ("WINDOW / SESSION", "PANE"),
    ("c", "new window", "n/e/u/i", "split L/D/U/R"),
    ("1..9", "select window", "z", "zoom / restore"),
    ("s", "session tree", "q", "show pane numbers"),
    ("W", "window tree", "x", "kill pane"),
    (".", "rename session", "< / >", "swap pane"),
    (",", "rename window", "Space", "next layout"),
    ("l / y", "move session", "C-g", "sync input"),
    ("C-p/C-n", "prev/next window", "[", "copy mode"),
    ("WORKFLOW", "SYSTEM"),
    ("a", "Codex tasks", "r", "reload config"),
    ("S", "save checkpoint", "R", "refresh client"),
    ("P", "restore snapshot", "t", "IAP window bar"),
    ("U", "eject storage", "C-s", "send prefix"),
    ("I", "restore storage", "Esc", "close help"),
]


def tmux(args: List[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["tmux", *args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
    )


def current_client() -> str:
    result = subprocess.run(
        ["tmux", "display-message", "-p", "#{client_tty}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def fit(text: str, width: int) -> str:
    return text[:width].ljust(width)


def entry(key: str, description: str, width: int) -> str:
    key_width = 9
    plain = f" {key:<{key_width}} {description}"
    padding = max(0, width - len(plain))
    return (
        f" {CYAN}{BOLD}{key:<{key_width}}{RESET} "
        f"{TEXT}{description}{' ' * padding}{RESET}"
    )


def section(title: str, width: int) -> str:
    line = max(1, width - len(title) - 3)
    return f" {PINK}{BOLD}{title}{RESET} {MUTED}{'─' * line}{RESET}"


def draw() -> None:
    columns, lines = shutil.get_terminal_size((64, 19))
    inner = max(24, columns - 2)
    gap = 2
    column = max(20, (inner - gap) // 2)
    output = ["\033[2J\033[H"]
    for row in ROWS:
        if len(row) == 2:
            left = section(row[0], column)
            right = section(row[1], column)
        else:
            left = entry(row[0], row[1], column)
            right = entry(row[2], row[3], column)
        output.append(f"{left}{' ' * gap}{right}")
    footer = "Any other key keeps its original tmux binding"
    output.append("")
    output.append(f" {GOLD}{fit(footer, min(inner, len(footer)))}{RESET}")
    while len(output) < lines:
        output.append("")
    sys.stdout.write("\r\n".join(output))
    sys.stdout.flush()


def read_key() -> Optional[str]:
    fd = sys.stdin.fileno()
    previous = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        first = os.read(fd, 1)
        if not first:
            return None
        value = first[0]
        if value == 27:
            ready, _, _ = select.select([fd], [], [], 0.08)
            if not ready:
                return None
            sequence = first + os.read(fd, 8)
            arrows = {
                b"\x1b[A": "Up",
                b"\x1b[B": "Down",
                b"\x1b[C": "Right",
                b"\x1b[D": "Left",
            }
            return arrows.get(sequence)
        if value == 32:
            return "Space"
        if 1 <= value <= 26:
            return f"C-{chr(value + 96)}"
        if value in (10, 13):
            return "Enter"
        if value == 127:
            return "BSpace"
        return first.decode("utf-8", errors="ignore") or None
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, previous)


def dispatch(client_tty: str, key: str) -> int:
    time.sleep(0.12)
    if tmux(["switch-client", "-c", client_tty, "-T", "prefix"]).returncode != 0:
        return 1
    return tmux(["send-keys", "-K", "-c", client_tty, key]).returncode


def ui(client_tty: str = "") -> int:
    if not client_tty or "#{" in client_tty:
        client_tty = current_client()
    if not client_tty:
        return 1
    draw()
    key = read_key()
    if not key:
        return 0
    subprocess.Popen(
        [sys.executable, str(Path(__file__).resolve()), "dispatch", client_tty, key],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return 0


def main(argv: List[str]) -> int:
    if len(argv) in (2, 3) and argv[1] == "ui":
        return ui(argv[2] if len(argv) == 3 else "")
    if len(argv) == 4 and argv[1] == "dispatch":
        return dispatch(argv[2], argv[3])
    print(f"usage: {argv[0]} ui [client-tty] | dispatch client-tty key", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

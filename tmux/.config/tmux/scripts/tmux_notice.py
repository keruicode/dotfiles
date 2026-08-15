#!/usr/bin/env python3

import os
import shlex
import subprocess
import sys
import uuid
from pathlib import Path
from typing import List


OPTION = "@dotfiles_notice"
TOKEN_OPTION = "@dotfiles_notice_token"
COLORS = {
    "ok": ("#a6e3a1", "OK"),
    "warn": ("#ffd27d", "!"),
    "error": ("#ff6b81", "ERR"),
    "info": ("#88e5f2", "i"),
}


def tmux(args: List[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["tmux", *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def clean(message: str) -> str:
    return " ".join(message.replace("#", "").split())


def show(level: str, duration: float, message: str) -> int:
    color, label = COLORS.get(level, COLORS["info"])
    token = uuid.uuid4().hex
    rendered = (
        f"#[fg={color},bg=#282a36,bold] {label} "
        f"#[fg=#f8f8f2,nobold]{clean(message)} #[default]"
    )
    tmux(["set-option", "-gq", TOKEN_OPTION, token])
    tmux(["set-option", "-gq", OPTION, rendered])
    tmux(["refresh-client", "-S"])

    script = Path(__file__).resolve()
    command = (
        f"sleep {max(1.0, duration):.1f}; "
        f"{shlex.quote(str(script))} clear {shlex.quote(token)}"
    )
    tmux(["run-shell", "-b", command])
    return 0


def clear(token: str) -> int:
    current = tmux(["show-option", "-gqv", TOKEN_OPTION])
    if current.returncode != 0 or current.stdout.strip() != token:
        return 0
    tmux(["set-option", "-gu", OPTION])
    tmux(["set-option", "-gu", TOKEN_OPTION])
    tmux(["refresh-client", "-S"])
    return 0


def main(argv: List[str]) -> int:
    if len(argv) >= 5 and argv[1] == "show":
        try:
            duration = float(argv[3])
        except ValueError:
            duration = 4.0
        return show(argv[2], duration, " ".join(argv[4:]))
    if len(argv) == 3 and argv[1] == "clear":
        return clear(argv[2])
    print(
        f"usage: {argv[0]} show ok|warn|error|info seconds message | clear token",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

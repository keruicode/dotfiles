# Lightweight title generator for Kitty's native powerline tab bar.
# It mirrors the semantic labels used by the WezTerm configuration.

from __future__ import annotations

import os
import re


def _shorten(text: str, max_len: int = 18) -> str:
    text = text.strip()
    if len(text) <= max_len:
        return text
    return text[: max_len - 1] + "…"


def _clean_title(title: str) -> str:
    title = title.strip() or "shell"
    lowered = title.lower()

    if "yazi" in lowered:
        path = title.split(":", 1)[-1].strip()
        directory = path.rstrip("/").split("/")[-1] if "/" in path else ""
        return _shorten(f"Yazi · {directory}" if directory else "Yazi")
    if "lazygit" in lowered:
        return "git"
    if "codex" in lowered:
        return "Codex"
    if "nvim" in lowered or title.lower() == "vim":
        return "nvim"

    # Remove noisy common prefixes/suffixes from Kitty/Yazi/window titles.
    title = title.replace(" — kitty", "")
    title = title.replace(" - kitty", "")

    home = os.path.expanduser("~")
    if title == home or title == "~":
        return "mac"
    title = title.replace(home, "~")

    # Use the final path component for long cwd-like titles.
    if "/" in title and not title.startswith("ssh"):
        tail = title.rstrip("/").split("/")[-1]
        if tail:
            title = tail

    if re.search(r"\b(base|zsh|bash|fish)\b", title, re.I):
        return "mac"

    return _shorten(title, 18)


def _icon_for(text: str) -> str:
    s = text.lower()
    pairs = [
        ("󰇥", ("yazi", "ranger")),
        ("", ("nvim", "vim")),
        ("", ("git", "lazygit")),
        ("󱜙", ("codex",)),
        ("󰣀", ("ssh", "iap", "fly", "huan", "earth")),
        ("", ("python", "ipython", "conda")),
        ("", ("node", "npm", "pnpm", "yarn")),
        ("󱃾", ("orbstack", "docker")),
        ("󰘳", ("mac", "zsh", "bash", "shell")),
    ]
    for icon, keys in pairs:
        if any(k in s for k in keys):
            return icon
    return "󰌽"


def draw_title(data: dict) -> str:
    """Called by tab_title_template '{custom}'."""
    title = _clean_title(str(data.get("title", "")))
    icon = _icon_for(title)
    idx = data.get("index", "")
    count = data.get("num_windows", 1)
    multi = f" ·{count}" if isinstance(count, int) and count > 1 else ""
    return f" {idx} {icon} {title}{multi} "

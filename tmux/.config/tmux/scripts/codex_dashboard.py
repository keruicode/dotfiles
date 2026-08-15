#!/usr/bin/env python3

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple


HOME = Path.home()
SESSIONS_DIR = HOME / ".codex/sessions"
TAIL_BYTES = 2 * 1024 * 1024

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
AMBER = "\033[38;2;255;210;125m"
CORAL = "\033[38;2;255;107;129m"
CYAN = "\033[38;2;136;229;242m"
MINT = "\033[38;2;168;242;194m"
MUTED = "\033[38;2;113;121;138m"
WHITE = "\033[38;2;248;248;242m"

UUID_RE = re.compile(r"\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b", re.I)
ATTENTION_RE = re.compile(
    r"approval|approve|permission|confirm|do you want|would you like|"
    r"press enter to|allow this|request user input",
    re.I,
)
WORKING_RE = re.compile(
    r"Working \((?:(\d+)h )?(?:(\d+)m )?(\d+)s(?: [•·]|\))"
)


def run(args: List[str], timeout: float = 4.0) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
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
    return run(["tmux", *args])


def clean_session(name: str) -> str:
    return re.sub(r"^\d+-", "", name)


def compact_path(path: str, width: int = 24) -> str:
    home = str(HOME)
    display = f"~{path[len(home):]}" if path == home or path.startswith(f"{home}/") else path
    parts = display.split("/")
    if len(display) <= width:
        return display
    leaf = parts[-1] or parts[-2]
    if len(leaf) >= width - 2:
        return f"…{leaf[-(width - 1):]}"
    return f"…/{leaf}"


def truncate(text: str, width: int) -> str:
    normalized = " ".join(text.split())
    if len(normalized) <= width:
        return normalized
    return f"{normalized[: max(1, width - 1)]}…"


def duration(seconds: Optional[float]) -> str:
    if seconds is None or seconds < 0:
        return ""
    value = int(seconds)
    if value < 60:
        return f"{value}s"
    if value < 3600:
        return f"{value // 60}m"
    if value < 86400:
        return f"{value // 3600}h"
    return f"{value // 86400}d"


def list_panes() -> List[Dict[str, object]]:
    fmt = (
        "#{session_id}\t#{session_name}\t#{window_id}\t#{window_index}"
        "\t#{window_name}\t#{pane_id}\t#{pane_index}\t#{pane_pid}"
        "\t#{pane_current_command}\t#{pane_current_path}\t#{pane_active}"
    )
    result = tmux(["list-panes", "-a", "-F", fmt])
    panes: List[Dict[str, object]] = []
    if result.returncode != 0:
        return panes
    for line in result.stdout.splitlines():
        fields = line.split("\t", 10)
        if len(fields) != 11:
            continue
        (
            session_id,
            session_name,
            window_id,
            window_index,
            window_name,
            pane_id,
            pane_index,
            pane_pid,
            command,
            path,
            active,
        ) = fields
        panes.append(
            {
                "session_id": session_id,
                "session_name": session_name,
                "window_id": window_id,
                "window_index": window_index,
                "window_name": window_name,
                "pane_id": pane_id,
                "pane_index": pane_index,
                "pane_pid": int(pane_pid),
                "command": command,
                "path": path,
                "active": active == "1",
            }
        )
    return panes


def foreground_process(pane_pid: int) -> Tuple[str, str]:
    foreground = run(["ps", "-o", "tpgid=", "-p", str(pane_pid)])
    value = foreground.stdout.strip()
    if foreground.returncode != 0 or not value.isdigit():
        return "", ""
    process = run(["ps", "-o", "comm=", "-o", "command=", "-p", value])
    if process.returncode != 0:
        return "", ""
    line = process.stdout.strip()
    if not line:
        return "", ""
    parts = line.split(None, 1)
    return Path(parts[0]).name, parts[1] if len(parts) > 1 else parts[0]


def thread_id(command: str) -> str:
    match = UUID_RE.search(command)
    return match.group(0).lower() if match else ""


def log_index() -> Dict[str, Path]:
    index: Dict[str, Path] = {}
    if not SESSIONS_DIR.exists():
        return index
    for path in SESSIONS_DIR.rglob("*.jsonl"):
        match = UUID_RE.search(path.name)
        if not match:
            continue
        key = match.group(0).lower()
        previous = index.get(key)
        if previous is None or path.stat().st_mtime > previous.stat().st_mtime:
            index[key] = path
    return index


def tail_text(path: Path) -> str:
    try:
        with path.open("rb") as handle:
            size = handle.seek(0, os.SEEK_END)
            handle.seek(max(0, size - TAIL_BYTES))
            data = handle.read()
        if size > TAIL_BYTES:
            data = data.split(b"\n", 1)[-1]
        return data.decode("utf-8", errors="replace")
    except OSError:
        return ""


def latest_task(path: Optional[Path]) -> Dict[str, object]:
    latest: Dict[str, object] = {}
    if path is None:
        return latest
    for line in tail_text(path).splitlines():
        if not any(name in line for name in ("task_started", "task_complete", "turn_aborted")):
            continue
        try:
            record = json.loads(line)
        except (ValueError, TypeError):
            continue
        payload = record.get("payload", {})
        event = payload.get("type", "")
        if event not in {"task_started", "task_complete", "turn_aborted"}:
            continue
        latest = {
            "event": event,
            "timestamp": record.get("timestamp", ""),
            "started_at": payload.get("started_at"),
            "completed_at": payload.get("completed_at"),
            "summary": payload.get("last_agent_message", ""),
        }
    return latest


def capture(pane_id: str, lines: int = 32) -> str:
    result = tmux(["capture-pane", "-p", "-t", pane_id, "-S", f"-{lines}"])
    return result.stdout if result.returncode == 0 else ""


def classify(screen: str, task: Dict[str, object]) -> Tuple[str, Optional[float]]:
    now = time.time()
    recent = "\n".join(screen.splitlines()[-24:])
    if ATTENTION_RE.search(recent):
        return "attention", None
    if "Working (" in recent and "esc to interrupt" in recent:
        started_at = task.get("started_at")
        if isinstance(started_at, (int, float)):
            return "running", now - float(started_at)
        match = WORKING_RE.search(recent)
        if match:
            hours, minutes, seconds = (int(value or 0) for value in match.groups())
            return "running", hours * 3600 + minutes * 60 + seconds
        return "running", None
    event = task.get("event")
    if event == "task_started":
        started_at = task.get("started_at")
        return "running", now - float(started_at) if isinstance(started_at, (int, float)) else None
    if event == "task_complete":
        completed_at = task.get("completed_at")
        return "completed", now - float(completed_at) if isinstance(completed_at, (int, float)) else None
    if event == "turn_aborted":
        return "attention", None
    return "ready", None


def status_style(status: str) -> Tuple[str, str, str]:
    return {
        "attention": (CORAL, "!", "待处理"),
        "running": (AMBER, "●", "运行中"),
        "completed": (MINT, "✓", "已完成"),
        "ready": (MUTED, "○", "就绪"),
    }[status]


def collect() -> List[Dict[str, object]]:
    panes = list_panes()
    candidates = []
    for pane in panes:
        process, command = foreground_process(int(pane["pane_pid"]))
        if process != "codex" and str(pane["command"]) != "codex":
            continue
        pane["process_command"] = command
        pane["thread_id"] = thread_id(command)
        candidates.append(pane)

    logs = log_index()
    rows = []
    for pane in candidates:
        log_path = logs.get(str(pane["thread_id"]))
        task = latest_task(log_path)
        screen = capture(str(pane["pane_id"]))
        status, age = classify(screen, task)
        summary = str(task.get("summary", ""))
        rows.append(
            {
                **pane,
                "status": status,
                "age": age,
                "summary": truncate(summary, 240) if summary else "",
                "log_path": str(log_path) if log_path else "",
                "on_storage": str(pane["path"]).startswith("/Volumes/storage/"),
            }
        )
    order = {"attention": 0, "running": 1, "completed": 2, "ready": 3}
    rows.sort(
        key=lambda row: (
            order[str(row["status"])],
            str(row["session_name"]),
            int(str(row["window_index"])),
            int(str(row["pane_index"])),
        )
    )
    return rows


def location(row: Dict[str, object]) -> str:
    session = clean_session(str(row["session_name"]))
    pane_suffix = f".{row['pane_index']}" if int(str(row["pane_index"])) > 1 else ""
    return f"{session} / {row['window_name']}{pane_suffix}"


def plain(rows: List[Dict[str, object]]) -> int:
    if not rows:
        print("No Codex panes are running in tmux.")
        return 0
    for row in rows:
        _, marker, label = status_style(str(row["status"]))
        storage = "  [storage]" if row["on_storage"] else ""
        print(
            f"{marker} {label:<7} {location(row):<30} "
            f"{compact_path(str(row['path']), 32):<32} {duration(row['age']):>5}{storage}"
        )
    return 0


def jump(client_tty: str, pane_id: str) -> bool:
    client_args = ["-c", client_tty] if client_tty else []
    return tmux(["switch-client", *client_args, "-t", pane_id]).returncode == 0


def popup(client_tty: str) -> int:
    rows = collect()
    if not rows:
        print("\n  No Codex panes\n\n  Esc  close")
        try:
            input()
        except (EOFError, KeyboardInterrupt):
            pass
        return 0

    counts = {name: sum(row["status"] == name for row in rows) for name in status_style_names()}
    header = (
        f"  ● {counts['running']} running   ✓ {counts['completed']} completed"
        f"   ! {counts['attention']} attention"
    )
    lines = []
    for row in rows:
        color, marker, label = status_style(str(row["status"]))
        place = truncate(location(row), 27)
        project = compact_path(str(row["path"]), 22)
        age = duration(row["age"])
        disk = f" {CORAL}storage{RESET}" if row["on_storage"] else ""
        visible = (
            f"{color}{BOLD}{marker} {label:<7}{RESET}  "
            f"{WHITE}{place:<27}{RESET}  {DIM}{project:<22}{RESET}"
            f"  {MUTED}{age:>4}{RESET}{disk}"
        )
        lines.append(f"{row['pane_id']}\t{visible}")

    preview = "tmux capture-pane -ep -t {1} -S -18 2>/dev/null | tail -18"
    command = [
        "fzf",
        "--ansi",
        "--delimiter=\t",
        "--with-nth=2..",
        "--layout=reverse",
        "--info=inline-right",
        "--border=none",
        "--no-separator",
        "--no-scrollbar",
        "--prompt=Jump > ",
        f"--header={header}",
        "--pointer=▸",
        "--marker=✓",
        "--color=bg:#282a36,bg+:#414955,fg:#f8f8f2,fg+:#f8f8f2,hl:#88e5f2,hl+:#88e5f2,info:#71798a,prompt:#ff6b81,pointer:#88e5f2,marker:#a8f2c2,header:#b6beca,gutter:#282a36",
        "--bind=ctrl-u:up,ctrl-e:down,double-click:accept",
        f"--preview={preview}",
        "--preview-window=down,45%,border-top,wrap",
        "--preview-label= pane output ",
    ]
    result = subprocess.run(
        command,
        input="\n".join(lines) + "\n",
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return 0
    pane_id = result.stdout.split("\t", 1)[0].strip()
    return 0 if jump(client_tty, pane_id) else 1


def status_style_names() -> Tuple[str, ...]:
    return "attention", "running", "completed", "ready"


def main(argv: List[str]) -> int:
    command = argv[1] if len(argv) > 1 else "status"
    if command == "status":
        return plain(collect())
    if command == "json":
        print(json.dumps(collect(), ensure_ascii=False, indent=2))
        return 0
    if command == "popup":
        return popup(argv[2] if len(argv) > 2 else "")
    if command == "jump" and len(argv) >= 4:
        return 0 if jump(argv[2], argv[3]) else 1
    print(f"usage: {argv[0]} status|json|popup [client-tty]|jump client-tty pane-id", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

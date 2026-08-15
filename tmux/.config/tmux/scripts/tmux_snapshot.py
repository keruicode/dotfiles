#!/usr/bin/env python3

import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterator, List, Optional, Set, Tuple


HOME = Path.home()
RESURRECT_DIR = Path(
    os.environ.get(
        "TMUX_SNAPSHOT_RESURRECT_DIR",
        HOME / ".local/share/tmux/resurrect",
    )
)
SAVE_SCRIPT = Path(
    os.environ.get(
        "TMUX_SNAPSHOT_SAVE_SCRIPT",
        HOME / ".config/tmux/plugins/tmux-resurrect/scripts/save.sh",
    )
)
STATE_PATH = HOME / ".local/state/tmux/storage-workspace.json"
CHECKPOINTS_DIR = RESURRECT_DIR / "checkpoints"
PANE_ARCHIVE = RESURRECT_DIR / "pane_contents.tar.gz"
LAST_LINK = RESURRECT_DIR / "last"
NOTICE_SCRIPT = Path(__file__).resolve().with_name("tmux_notice.py")


class SnapshotError(RuntimeError):
    pass


def run(
    args: List[str], timeout: float = 60.0
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        raise SnapshotError(f"command timed out: {' '.join(args)}") from error


def tmux(args: List[str], timeout: float = 10.0) -> subprocess.CompletedProcess[str]:
    return run(["tmux", *args], timeout=timeout)


def notify(message: str, quiet: bool = False, level: str = "info") -> None:
    if quiet:
        return
    if os.environ.get("TMUX"):
        run([str(NOTICE_SCRIPT), "show", level, "5", message], timeout=4.0)
    else:
        print(message)


def topology_from_tmux() -> Dict[str, object]:
    sessions_result = tmux(["list-sessions", "-F", "#{session_name}"])
    windows_result = tmux(["list-windows", "-a", "-F", "#{session_name}\t#{window_id}"])
    panes_result = tmux(["list-panes", "-a", "-F", "#{session_name}\t#{pane_id}"])
    if any(
        result.returncode != 0
        for result in (sessions_result, windows_result, panes_result)
    ):
        raise SnapshotError("tmux server topology could not be read")
    sessions = sorted(line for line in sessions_result.stdout.splitlines() if line)
    return {
        "sessions": sessions,
        "session_count": len(sessions),
        "window_count": len([line for line in windows_result.stdout.splitlines() if line]),
        "pane_count": len([line for line in panes_result.stdout.splitlines() if line]),
    }


def topology_from_snapshot(path: Path) -> Dict[str, object]:
    sessions: Set[str] = set()
    window_count = 0
    pane_count = 0
    try:
        with path.open(encoding="utf-8") as handle:
            for raw_line in handle:
                fields = raw_line.rstrip("\n").split("\t")
                if not fields:
                    continue
                if fields[0] == "pane" and len(fields) > 1:
                    sessions.add(fields[1])
                    pane_count += 1
                elif fields[0] == "window" and len(fields) > 1:
                    sessions.add(fields[1])
                    window_count += 1
                elif fields[0] == "grouped_session" and len(fields) > 1:
                    sessions.add(fields[1])
    except OSError as error:
        raise SnapshotError(f"cannot read snapshot: {path}") from error
    return {
        "sessions": sorted(sessions),
        "session_count": len(sessions),
        "window_count": window_count,
        "pane_count": pane_count,
    }


def resolve_last() -> Path:
    if not LAST_LINK.exists():
        raise SnapshotError(f"missing Resurrect snapshot link: {LAST_LINK}")
    try:
        snapshot = LAST_LINK.resolve(strict=True)
    except OSError as error:
        raise SnapshotError(f"broken Resurrect snapshot link: {LAST_LINK}") from error
    if not snapshot.is_file():
        raise SnapshotError(f"invalid Resurrect snapshot: {snapshot}")
    return snapshot


def validate_archive(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise SnapshotError("pane scrollback archive was not created")
    try:
        with tarfile.open(path, "r:gz") as archive:
            members = archive.getmembers()
    except (OSError, tarfile.TarError) as error:
        raise SnapshotError("pane scrollback archive is corrupt") from error
    if not any(member.isfile() for member in members):
        raise SnapshotError("pane scrollback archive contains no pane data")


def validate_snapshot(snapshot: Path, expected: Dict[str, object]) -> Dict[str, object]:
    actual = topology_from_snapshot(snapshot)
    keys = ("session_count", "window_count", "pane_count")
    mismatches = [
        f"{key} expected={expected[key]} saved={actual[key]}"
        for key in keys
        if expected[key] != actual[key]
    ]
    if expected["sessions"] != actual["sessions"]:
        mismatches.append(
            f"sessions expected={expected['sessions']} saved={actual['sessions']}"
        )
    if mismatches:
        raise SnapshotError("snapshot verification failed: " + "; ".join(mismatches))
    validate_archive(PANE_ARCHIVE)
    return actual


@contextmanager
def save_lock() -> Iterator[None]:
    lock_path = Path(f"/tmp/tmux-dotfiles-snapshot-{os.getuid()}.lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        yield


def save_verified() -> Tuple[Path, Dict[str, object]]:
    if not SAVE_SCRIPT.is_file():
        raise SnapshotError(f"tmux-resurrect save script is missing: {SAVE_SCRIPT}")
    expected = topology_from_tmux()
    with save_lock():
        result = run([str(SAVE_SCRIPT), "quiet"], timeout=120.0)
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip().splitlines()
            raise SnapshotError(
                f"tmux-resurrect save failed: {detail[-1] if detail else result.returncode}"
            )
        snapshot = resolve_last()
        actual = validate_snapshot(snapshot, expected)
    return snapshot, actual


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def clean_label(label: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", label.strip()).strip("-.")
    return cleaned or "manual"


def new_checkpoint_dir(timestamp: str, label: str) -> Path:
    base = CHECKPOINTS_DIR / f"{timestamp}-{clean_label(label)}"
    candidate = base
    suffix = 2
    while candidate.exists():
        candidate = Path(f"{base}-{suffix}")
        suffix += 1
    candidate.mkdir(parents=True)
    return candidate


def write_checkpoint(
    snapshot: Path,
    topology: Dict[str, object],
    label: str,
    include_archive: bool,
) -> Path:
    timestamp = datetime.now().strftime("%Y%m%dT%H%M%S")
    target = new_checkpoint_dir(timestamp, label)
    layout_target = target / "layout.txt"
    shutil.copy2(snapshot, layout_target)
    archive_target: Optional[Path] = None
    if include_archive:
        validate_archive(PANE_ARCHIVE)
        archive_target = target / PANE_ARCHIVE.name
        shutil.copy2(PANE_ARCHIVE, archive_target)
    if STATE_PATH.is_file():
        shutil.copy2(STATE_PATH, target / STATE_PATH.name)

    manifest = {
        "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "label": label,
        "source_snapshot": str(snapshot),
        "layout_sha256": sha256(layout_target),
        "pane_archive_sha256": sha256(archive_target) if archive_target else None,
        "pane_contents_included": archive_target is not None,
        "topology": topology,
        "storage_mounted": Path("/Volumes/storage").is_mount(),
    }
    with (target / "manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    CHECKPOINTS_DIR.mkdir(parents=True, exist_ok=True)
    latest = CHECKPOINTS_DIR / "latest"
    temporary = CHECKPOINTS_DIR / ".latest.tmp"
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(target.name)
    temporary.replace(latest)
    return target


def command_checkpoint(label: str, quiet: bool) -> int:
    snapshot, topology = save_verified()
    target = write_checkpoint(snapshot, topology, label, include_archive=True)
    notify(
        "tmux checkpoint saved"
        f" · {topology['session_count']} sessions"
        f" · {topology['window_count']} windows"
        f" · {topology['pane_count']} panes",
        quiet=quiet,
        level="ok",
    )
    if not quiet and not os.environ.get("TMUX"):
        print(target)
    return 0


def command_quiet_save() -> int:
    save_verified()
    return 0


def command_preserve(snapshot_name: str, label: str) -> int:
    snapshot = Path(snapshot_name).expanduser()
    if not snapshot.is_absolute():
        snapshot = RESURRECT_DIR / snapshot
    snapshot = snapshot.resolve(strict=True)
    topology = topology_from_snapshot(snapshot)
    target = write_checkpoint(snapshot, topology, label, include_archive=False)
    print(f"preserved layout-only checkpoint: {target}")
    return 0


def list_checkpoints(limit: int) -> int:
    if not CHECKPOINTS_DIR.is_dir():
        print("no checkpoints")
        return 0
    checkpoints = sorted(
        (
            path
            for path in CHECKPOINTS_DIR.iterdir()
            if path.is_dir()
            and not path.is_symlink()
            and (path / "manifest.json").is_file()
        ),
        reverse=True,
    )[:limit]
    if not checkpoints:
        print("no checkpoints")
        return 0
    print("checkpoint\tsessions\twindows\tpanes\tscrollback")
    for checkpoint in checkpoints:
        with (checkpoint / "manifest.json").open(encoding="utf-8") as handle:
            manifest = json.load(handle)
        topology = manifest["topology"]
        scrollback = "yes" if manifest.get("pane_contents_included") else "no"
        print(
            f"{checkpoint.name}\t{topology['session_count']}"
            f"\t{topology['window_count']}\t{topology['pane_count']}\t{scrollback}"
        )
    return 0


def command_prepare(checkpoint_name: str) -> int:
    checkpoint = Path(checkpoint_name).expanduser()
    if not checkpoint.is_absolute():
        checkpoint = CHECKPOINTS_DIR / checkpoint
    checkpoint = checkpoint.resolve(strict=True)
    layout = checkpoint / "layout.txt"
    manifest_path = checkpoint / "manifest.json"
    if not layout.is_file() or not manifest_path.is_file():
        raise SnapshotError(f"not a checkpoint: {checkpoint}")

    current = topology_from_tmux()
    if current["session_count"] > 1 or current["pane_count"] > 1:
        raise SnapshotError(
            "restore preparation refused: start with a fresh tmux server containing one pane"
        )

    archive = checkpoint / PANE_ARCHIVE.name
    if archive.is_file():
        validate_archive(archive)
        shutil.copy2(archive, PANE_ARCHIVE)
    else:
        PANE_ARCHIVE.unlink(missing_ok=True)

    LAST_LINK.unlink(missing_ok=True)
    LAST_LINK.symlink_to(os.path.relpath(layout, RESURRECT_DIR))
    print(f"prepared checkpoint: {checkpoint.name}")
    print("press C-s P to restore it")
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Verified tmux Resurrect checkpoints")
    subparsers = result.add_subparsers(dest="command", required=True)

    checkpoint = subparsers.add_parser("checkpoint")
    checkpoint.add_argument("label", nargs="?", default="manual")
    checkpoint.add_argument("--quiet", action="store_true")

    subparsers.add_parser("quiet")

    preserve = subparsers.add_parser("preserve")
    preserve.add_argument("snapshot")
    preserve.add_argument("label", nargs="?", default="preserved")

    listing = subparsers.add_parser("list")
    listing.add_argument("--limit", type=int, default=20)

    prepare = subparsers.add_parser("prepare")
    prepare.add_argument("checkpoint")
    return result


def main(argv: List[str]) -> int:
    args = parser().parse_args(argv[1:])
    try:
        if args.command == "checkpoint":
            return command_checkpoint(args.label, args.quiet)
        if args.command == "quiet":
            return command_quiet_save()
        if args.command == "preserve":
            return command_preserve(args.snapshot, args.label)
        if args.command == "list":
            return list_checkpoints(args.limit)
        if args.command == "prepare":
            return command_prepare(args.checkpoint)
    except (OSError, ValueError, json.JSONDecodeError, SnapshotError) as error:
        message = f"tmux snapshot failed · {error}"
        if os.environ.get("TMUX"):
            run([str(NOTICE_SCRIPT), "show", "error", "6", message], timeout=4.0)
        else:
            print(message, file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

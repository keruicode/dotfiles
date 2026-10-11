import importlib.util
import io
import os
import subprocess
import sys
import tarfile
import time
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parents[1] / ".config/tmux/scripts/tmux_snapshot.py"
SPEC = importlib.util.spec_from_file_location("tmux_snapshot", SCRIPT)
snapshot = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(snapshot)
TOPOLOGY = {
    "sessions": ["work"],
    "session_count": 1,
    "window_count": 1,
    "pane_count": 1,
}
LAYOUT = "pane\twork\t1\t0\t:*\t1\nwindow\twork\t1\n"


@pytest.fixture(autouse=True)
def isolated_lock(tmp_path, monkeypatch):
    monkeypatch.setattr(snapshot, "LOCK_PATH", tmp_path / "snapshot.lock")


def make_archive(path, names=("pane-work:1.1",)):
    with tarfile.open(path, "w:gz") as archive:
        for name in names:
            content = b"saved history\n"
            member = tarfile.TarInfo(f"pane_contents/{name}")
            member.size = len(content)
            archive.addfile(member, io.BytesIO(content))


@pytest.fixture
def workspace(tmp_path, monkeypatch):
    root = tmp_path / "resurrect"
    root.mkdir()
    old = root / "tmux_resurrect_old.txt"
    old.write_text(LAYOUT, encoding="utf-8")
    (root / "last").symlink_to(old.name)
    make_archive(root / "pane_contents.tar.gz")
    monkeypatch.setattr(snapshot, "RESURRECT_DIR", root)
    monkeypatch.setattr(snapshot, "LAST_LINK", root / "last")
    monkeypatch.setattr(snapshot, "PANE_ARCHIVE", root / "pane_contents.tar.gz")
    monkeypatch.setattr(snapshot, "CHECKPOINTS_DIR", root / "checkpoints")
    monkeypatch.setattr(snapshot, "STATE_PATH", tmp_path / "no-state")
    monkeypatch.setattr(snapshot, "SAVE_SCRIPT", SCRIPT)
    monkeypatch.setattr(snapshot, "topology_from_tmux", lambda: dict(TOPOLOGY))
    monkeypatch.setattr(snapshot, "required_scrollback", lambda: {"pane-work:1.1"})
    monkeypatch.setattr(snapshot, "prune_layouts", lambda current: None)
    return root


def stage_output(env, corrupt=False, layout=LAYOUT):
    staging = Path(env["TMUX_SNAPSHOT_STAGE_DIR"])
    target = staging / "tmux_resurrect_new.txt"
    target.write_text(layout, encoding="utf-8")
    (staging / "last").symlink_to(target.name)
    archive = staging / "pane_contents.tar.gz"
    if corrupt:
        archive.write_bytes(b"broken gzip")
    else:
        make_archive(archive)


@pytest.mark.parametrize("failure", ["timeout", "partial-layout", "corrupt-archive"])
def test_failed_save_keeps_last_good_pair(workspace, monkeypatch, failure):
    previous_link = os.readlink(snapshot.LAST_LINK)
    previous_archive = snapshot.PANE_ARCHIVE.read_bytes()

    def fake_run(args, timeout=60.0, env=None):
        stage_output(
            env,
            corrupt=failure == "corrupt-archive",
            layout="" if failure == "partial-layout" else LAYOUT,
        )
        if failure == "timeout":
            raise snapshot.SnapshotError("command timed out")
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(snapshot, "run", fake_run)
    with pytest.raises(snapshot.SnapshotError):
        snapshot.save_verified()
    assert os.readlink(snapshot.LAST_LINK) == previous_link
    assert snapshot.PANE_ARCHIVE.read_bytes() == previous_archive
    assert not list(workspace.glob(".pending-*"))
    assert not (workspace / "tmux_resurrect_new.txt").exists()


def test_success_promotes_only_verified_pair(workspace, monkeypatch):
    monkeypatch.setenv("_RESURRECT_FILE_PATH", "/should/not/be/used")

    def fake_run(args, timeout=60.0, env=None):
        assert "_RESURRECT_FILE_PATH" not in env
        assert os.readlink(snapshot.LAST_LINK) == "tmux_resurrect_old.txt"
        assert Path(env["TMUX_SNAPSHOT_STAGE_DIR"]).parent == workspace
        stage_output(env)
        assert os.readlink(snapshot.LAST_LINK) == "tmux_resurrect_old.txt"
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(snapshot, "run", fake_run)
    layout, topology = snapshot.save_verified()
    assert topology == TOPOLOGY
    assert layout == workspace / "tmux_resurrect_new.txt"
    assert snapshot.LAST_LINK.resolve() == layout
    snapshot.validate_archive(snapshot.PANE_ARCHIVE, {"pane-work:1.1"})


def test_changed_topology_keeps_previous_snapshot(workspace, monkeypatch):
    states = iter([dict(TOPOLOGY), {**TOPOLOGY, "pane_count": 2}])
    monkeypatch.setattr(snapshot, "topology_from_tmux", lambda: next(states))

    def fake_run(args, timeout=60.0, env=None):
        stage_output(env)
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(snapshot, "run", fake_run)
    with pytest.raises(snapshot.SnapshotError, match="changed during save"):
        snapshot.save_verified()
    assert os.readlink(snapshot.LAST_LINK) == "tmux_resurrect_old.txt"


def test_missing_pane_history_is_rejected(tmp_path):
    archive = tmp_path / "pane_contents.tar.gz"
    make_archive(archive)
    with pytest.raises(snapshot.SnapshotError, match="pane-work:1.2"):
        snapshot.validate_archive(archive, {"pane-work:1.1", "pane-work:1.2"})


def test_metadata_only_archive_is_not_scrollback(tmp_path):
    archive = tmp_path / "pane_contents.tar.gz"
    make_archive(archive, names=("._pane-work:1.1",))
    with pytest.raises(snapshot.SnapshotError, match="no pane data"):
        snapshot.validate_archive(archive)


def test_failed_promotion_rolls_back_archive(workspace, monkeypatch):
    previous = snapshot.PANE_ARCHIVE.read_bytes()
    original_replace = Path.replace

    def fail_last_link(path, target):
        if path.name == "next-last":
            raise OSError("promotion failed")
        return original_replace(path, target)

    def fake_run(args, timeout=60.0, env=None):
        stage_output(env)
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(snapshot, "run", fake_run)
    monkeypatch.setattr(Path, "replace", fail_last_link)
    with pytest.raises(OSError, match="promotion failed"):
        snapshot.save_verified()
    assert snapshot.PANE_ARCHIVE.read_bytes() == previous
    assert os.readlink(snapshot.LAST_LINK) == "tmux_resurrect_old.txt"
    assert not (workspace / "tmux_resurrect_new.txt").exists()


def test_tmux_shim_redirects_only_save_directory(tmp_path):
    env = {
        **os.environ,
        "TMUX_SNAPSHOT_STAGE_DIR": str(tmp_path),
        "TMUX_SNAPSHOT_TMUX": "/bin/echo",
    }
    shim = ["/bin/bash", str(snapshot.SAVE_TMUX_SHIM)]
    result = snapshot.run(shim + ["show-option", "-gqv", "@resurrect-dir"], env=env)
    assert result.stdout.strip() == str(tmp_path)
    result = snapshot.run(shim + ["list-panes", "-a"], env=env)
    assert result.stdout.strip() == "list-panes -a"


@pytest.mark.parametrize("ignore_term", [False, True])
def test_timeout_stops_child_writers(tmp_path, ignore_term):
    marker = tmp_path / "late-write"
    signal_setup = (
        "import signal; signal.signal(signal.SIGTERM, signal.SIG_IGN); "
        if ignore_term
        else ""
    )
    child = (
        signal_setup + "import time; from pathlib import Path; time.sleep(1); "
        f"Path({str(marker)!r}).write_text('orphan')"
    )
    parent = (
        signal_setup
        + f"import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',{child!r}]); "
        "time.sleep(20)"
    )
    with pytest.raises(snapshot.SnapshotError, match="timed out"):
        snapshot.run([sys.executable, "-c", parent], timeout=0.15)
    time.sleep(1.1)
    assert not marker.exists()


def test_invalid_command_output_does_not_crash_decoder():
    result = snapshot.run(
        [sys.executable, "-c", "import os; os.write(2,b'\\xff')"], timeout=2
    )
    assert result.returncode == 0
    assert result.stderr == "\ufffd"


def test_busy_lock_is_bounded(monkeypatch):
    monkeypatch.setattr(snapshot, "LOCK_TIMEOUT", 0.1)
    with snapshot.save_lock():
        with pytest.raises(snapshot.SnapshotBusy):
            with snapshot.save_lock():
                pytest.fail("lock unexpectedly acquired")


def test_background_save_skips_busy_lock(monkeypatch):
    def busy():
        raise snapshot.SnapshotBusy("already saving")

    monkeypatch.setattr(snapshot, "save_verified", busy)
    assert snapshot.command_quiet_save() == 0


def test_checkpoint_copy_is_inside_save_lock(workspace, monkeypatch):
    monkeypatch.setattr(snapshot, "LOCK_TIMEOUT", 0.05)
    monkeypatch.setattr(snapshot, "save_verified_locked", lambda: (SCRIPT, TOPOLOGY))

    def copy_checkpoint(*args, **kwargs):
        with pytest.raises(snapshot.SnapshotBusy):
            with snapshot.save_lock():
                pytest.fail("checkpoint archive was not protected")
        return workspace

    monkeypatch.setattr(snapshot, "write_checkpoint", copy_checkpoint)
    assert snapshot.command_checkpoint("test", quiet=True) == 0

import importlib.util
import subprocess
from pathlib import Path
from unittest.mock import Mock

SCRIPT = (
    Path(__file__).resolve().parents[1] / ".config/tmux/scripts/external_workspace.py"
)
SPEC = importlib.util.spec_from_file_location("external_workspace", SCRIPT)
WORKSPACE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(WORKSPACE)


def test_server_access_probe_quotes_paths(tmp_path, monkeypatch):
    directory = tmp_path / "volume with ' quotes"
    directory.mkdir()
    (directory / "entry").touch()

    def local_server(args):
        assert args[0] == "run-shell"
        return subprocess.run(
            args[1], shell=True, capture_output=True, text=True, check=False
        )

    # Execute only the generated, locally controlled command as a fake server.
    monkeypatch.setattr(WORKSPACE, "tmux", local_server)
    assert WORKSPACE.workspace_access_error(str(directory)) == ""
    assert WORKSPACE.workspace_access_error(str(directory / "missing"))


def test_denied_restore_does_not_switch_or_create_session(monkeypatch):
    config = {"name": "storage", "mount_point": "/Volumes/storage"}
    notify = Mock()
    audit = Mock()
    ensure_session = Mock()
    tmux = Mock()
    monkeypatch.setattr(WORKSPACE, "mounted", lambda _: True)
    monkeypatch.setattr(
        WORKSPACE,
        "workspace_access_error",
        lambda _: "ls: /Volumes/storage: Operation not permitted",
    )
    monkeypatch.setattr(WORKSPACE, "notify", notify)
    monkeypatch.setattr(WORKSPACE, "audit", audit)
    monkeypatch.setattr(WORKSPACE, "ensure_session", ensure_session)
    monkeypatch.setattr(WORKSPACE, "tmux", tmux)

    assert WORKSPACE.restore_locked(config) == 1
    ensure_session.assert_not_called()
    tmux.assert_not_called()
    assert "disk access denied" in notify.call_args.args[0]
    assert "Operation not permitted" in audit.call_args.args[1]

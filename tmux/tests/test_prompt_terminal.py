import subprocess
import time
import uuid
from pathlib import Path

import pytest

HELPER = Path(__file__).resolve().parents[2] / "zsh/.config/zsh/terminal.zsh"


@pytest.fixture
def server():
    socket = "prompt-regression-" + uuid.uuid4().hex

    def tmux(*args):
        return subprocess.run(
            ["tmux", "-L", socket, *args],
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        ).stdout

    tmux("-f", "/dev/null", "new-session", "-d", "-x", "100", "-y", "30", "/bin/zsh -f")
    try:
        yield tmux
    finally:
        tmux("kill-server")


def send(server, command):
    server("send-keys", "-l", command)
    server("send-keys", "Enter")


def wait_output(server, text):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        output = server("capture-pane", "-p", "-S", "-")
        if text in output and output.rstrip().endswith("READY>"):
            return output
        time.sleep(0.05)
    pytest.fail(f"Expected {text!r} in terminal output: {output!r}")


def test_output_survives_tui_exit_and_repeated_prompts(server):
    send(server, f"source {HELPER}; PS1='READY> '")
    wait_output(server, "READY> ")
    # A previous full-screen application leaves a saved cursor behind.
    send(server, "printf '\\033[?1049hTUI\\033[?1049l'; print MARKER_1")
    wait_output(server, "\nMARKER_1\n")
    send(server, "print MARKER_2")
    wait_output(server, "\nMARKER_2\n")
    send(server, "pwd; print MARKER_3")
    output = wait_output(server, "\nMARKER_3\n")
    for marker in ("MARKER_1", "MARKER_2", "MARKER_3"):
        assert f"\n{marker}\n" in output
    server("resize-window", "-x", "60", "-y", "20")
    server("resize-window", "-x", "100", "-y", "30")
    output = server("capture-pane", "-p", "-S", "-")
    assert "\nMARKER_1\n" in output
    assert "\nMARKER_2\n" in output


def test_stale_tui_modes_are_still_cleared(server):
    send(server, f"source {HELPER}; PS1='READY> '")
    wait_output(server, "READY> ")
    send(server, "printf '\\033[?1049h\\033[?1003h\\033[?1006h'; sleep 0.3")
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        active = server(
            "display-message",
            "-p",
            "#{alternate_on}/#{mouse_any_flag}/#{mouse_sgr_flag}",
        ).strip()
        if active == "1/1/1":
            break
        time.sleep(0.01)
    else:
        pytest.fail("The simulated TUI never enabled its terminal modes")
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        flags = server(
            "display-message",
            "-p",
            "#{alternate_on}/#{mouse_any_flag}/#{mouse_sgr_flag}",
        ).strip()
        if flags == "0/0/0":
            return
        time.sleep(0.05)
    pytest.fail(f"Stale TUI modes remained active: {flags}")

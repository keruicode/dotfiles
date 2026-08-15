#!/usr/bin/env bash
set -euo pipefail

pane_pid="${1:-}"
[[ "$pane_pid" =~ ^[0-9]+$ ]] || exit 0

# The pane shell's terminal foreground process group identifies the command the
# user is actually interacting with, even when it was launched from Yazi or a
# nested shell. The stock resurrect strategy only checks direct children.
foreground_pgid="$(ps -o tpgid= -p "$pane_pid" | tr -d ' ')"
[[ "$foreground_pgid" =~ ^[0-9]+$ ]] || exit 0

# A foreground process group equal to the pane shell means the pane is idle.
[[ "$foreground_pgid" != "$pane_pid" ]] || exit 0

ps -o args= -p "$foreground_pgid"

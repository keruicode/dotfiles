#!/usr/bin/env bash
set -euo pipefail

content=$(pbpaste | tr -d '\r')
[[ -n "$content" ]] || exit 0
tmux set-buffer -- "$content"
tmux paste-buffer -p -d


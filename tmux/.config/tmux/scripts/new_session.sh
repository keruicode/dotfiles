#!/usr/bin/env bash
set -euo pipefail

start_path="${1:-$PWD}"
target_client="${2:-}"
session_id=$(tmux new-session -d -P -F '#{session_id}' -c "$start_path")
if [[ -n "$target_client" ]]; then
  tmux switch-client -c "$target_client" -t "$session_id"
else
  tmux switch-client -t "$session_id"
fi

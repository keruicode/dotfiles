#!/usr/bin/env bash
set -euo pipefail

content=$(tr -d '\r')
tmux set-buffer -w -- "$content"
printf '%s' "$content" | pbcopy


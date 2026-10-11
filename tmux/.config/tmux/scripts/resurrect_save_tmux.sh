#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 3 && "$1" == show-option && "$2" == -gqv && "$3" == @resurrect-dir ]]; then
  printf '%s\n' "${TMUX_SNAPSHOT_STAGE_DIR:?}"
else
  exec "${TMUX_SNAPSHOT_TMUX:?}" "$@"
fi

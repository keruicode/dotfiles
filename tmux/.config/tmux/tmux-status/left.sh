#!/usr/bin/env bash
set -euo pipefail

current_id="${1:-}"
current_name="${2:-}"
status_bg="#282a36"
active_bg="#88e5f2"
active_fg="#282a36"
inactive_bg="#3b3e4d"
inactive_fg="#9aa0b4"
separator=""
max_label_width=18

trim_index() {
  local value="$1"
  if [[ "$value" =~ ^[0-9]+-(.*)$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    printf '%s' "$value"
  fi
}

sessions=$(tmux list-sessions -F '#{session_id}::#{session_name}' 2>/dev/null || true)
[[ -n "$sessions" ]] || exit 0

output=""
previous_bg="$status_bg"
while IFS= read -r entry; do
  [[ -n "$entry" ]] || continue
  session_id="${entry%%::*}"
  session_name="${entry#*::}"
  label=$(trim_index "$session_name")

  if (( ${#label} > max_label_width )); then
    label="${label:0:max_label_width-1}…"
  fi

  bg="$inactive_bg"
  fg="$inactive_fg"
  style=""
  if [[ "$session_id" == "$current_id" || "$session_name" == "$current_name" ]]; then
    bg="$active_bg"
    fg="$active_fg"
    style=",bold"
  fi

  output+="#[range=session|${session_id} fg=${previous_bg},bg=${bg}]${separator}"
  output+="#[fg=${fg},bg=${bg}${style}] ${label} #[norange]"
  previous_bg="$bg"
done <<< "$sessions"

output+="#[fg=${previous_bg},bg=${status_bg}]${separator}"
printf '%s' "$output"

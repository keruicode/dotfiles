#!/usr/bin/env bash

activity_option='@resurrect_activity'

activity_name() {
  case "$1" in
    Restoring*) printf 'restore' ;;
    Saving*) printf 'save' ;;
    *) printf '%s' "$1" ;;
  esac
}

clear_activity() {
  tmux set-option -gu "$activity_option" 2>/dev/null || true
  tmux refresh-client -S 2>/dev/null || true
}

run_activity() {
  local activity
  activity="$(activity_name "$1")"

  trap 'clear_activity; exit' INT TERM HUP
  tmux set-option -g "$activity_option" "$activity"
  tmux refresh-client -S 2>/dev/null || true

  while true; do
    sleep 1
  done
}

start_spinner() {
  run_activity "$1" &
  export SPINNER_PID=$!
}

stop_spinner() {
  if [[ -n "${SPINNER_PID:-}" ]]; then
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
  fi
  clear_activity
}

# tmux-resurrect sources this file after helpers.sh, so this replaces its
# full-width success message while preserving visible error messages.
display_message() {
  local message="$1"
  local display_duration="${2:-5000}"
  local saved_display_time

  case "$message" in
    'Tmux restore complete!'|'Tmux environment saved!') return ;;
  esac

  saved_display_time="$(tmux show-option -gqv display-time)"
  tmux set-option -gq display-time "$display_duration"
  tmux display-message "$message"
  tmux set-option -gq display-time "${saved_display_time:-750}"
}

#!/usr/bin/env bash
set -euo pipefail

action="${1:-toggle}"
pane_id=''

if [[ -n "${TMUX_PANE:-}" ]] && tmux display-message -p -t "$TMUX_PANE" '#{pane_id}' >/dev/null 2>&1; then
  active_record="$(tmux display-message -p -t "$TMUX_PANE" '#{pane_id}|#{@pane_label}|#{pane_current_command}')"
else
  active_record="$(tmux display-message -p '#{pane_id}|#{@pane_label}|#{pane_current_command}')"
fi
IFS='|' read -r active_pane active_label active_command <<<"$active_record"

if [[ "$active_label" == iap || "$active_label" == iap-[0-9]* ]] && [[ "$active_command" == bash ]]; then
  pane_id="$active_pane"
else
  while IFS='|' read -r candidate label command; do
    if [[ "$label" == iap || "$label" == iap-[0-9]* ]] && [[ "$command" == bash ]]; then
      pane_id="$candidate"
      break
    fi
  done < <(tmux list-panes -a -F '#{pane_id}|#{@pane_label}|#{pane_current_command}')
fi

if [[ -z "$pane_id" ]]; then
  tmux display-message 'IAP is not connected'
  exit 1
fi

status_option="@iap_remote_status_${pane_id#%}"
current_status="$(tmux show-options -gqv "$status_option" 2>/dev/null || true)"
[[ "$current_status" == on || "$current_status" == off ]] || current_status=off

case "$action" in
  on|off)
    new_status="$action"
    ;;
  toggle)
    if [[ "$current_status" == on ]]; then
      new_status=off
    else
      new_status=on
    fi
    ;;
  *)
    printf 'usage: %s [toggle|on|off]\n' "${0##*/}" >&2
    exit 2
    ;;
esac

tmux send-keys -t "$pane_id" C-b : "set-option status $new_status" Enter
tmux set-option -g "$status_option" "$new_status"

pane_label="$(tmux display-message -p -t "$pane_id" '#{@pane_label}')"
message="$pane_label remote window bar: $new_status"
tmux display-message "$message"

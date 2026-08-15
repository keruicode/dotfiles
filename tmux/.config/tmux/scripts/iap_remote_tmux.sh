#!/usr/bin/env bash
set -uo pipefail

readonly remote_user_host='elzd_2023_00026@10.64.201.2'
readonly remote_workdir='/data1/elpt_2022_00083/kerui'
readonly remote_session_base='iap'
readonly max_instances=20
readonly retry_delay=3

stop=false
final_status=130
lock_held=false
lock_file=''
local_pane_id=''
remote_session=''
instance_slot=0
parent_monitor_pid=''
readonly parent_pid=$PPID
readonly process_group_id="$(ps -p "$$" -o pgid= | tr -d ' ')"

acquire_instance() {
  local slot candidate

  for ((slot = 1; slot <= max_instances; slot++)); do
    candidate="/tmp/iap_remote_tmux.${UID}.${slot}.lock"
    if shlock -f "$candidate" -p "$$"; then
      lock_file="$candidate"
      lock_held=true
      instance_slot=$slot
      if ((slot == 1)); then
        remote_session="$remote_session_base"
      else
        remote_session="${remote_session_base}-${slot}"
      fi
      return
    fi
  done

  printf 'IAP instance limit reached (%s).\n' "$max_instances" >&2
  exit 1
}

release_lock() {
  if [[ "$lock_held" == true ]] && [[ "$(cat "$lock_file" 2>/dev/null || true)" == "$$" ]]; then
    rm -f "$lock_file"
  fi
}

detect_local_pane() {
  if [[ -n "${TMUX_PANE:-}" ]] && tmux display-message -p -t "$TMUX_PANE" '#{pane_id}' >/dev/null 2>&1; then
    local_pane_id="$TMUX_PANE"
    return
  fi

  local tty_path
  tty_path="$(tty 2>/dev/null || true)"
  while IFS='|' read -r pane_id pane_tty; do
    if [[ "$pane_tty" == "$tty_path" ]]; then
      local_pane_id="$pane_id"
      return
    fi
  done < <(tmux list-panes -a -F '#{pane_id}|#{pane_tty}' 2>/dev/null || true)
}

mark_local_pane() {
  if [[ -n "$local_pane_id" ]]; then
    tmux set-option -p -t "$local_pane_id" @pane_label "$remote_session" 2>/dev/null || true
    tmux set-option -g "@iap_remote_status_${local_pane_id#%}" off 2>/dev/null || true
  fi
}

clear_local_pane() {
  if [[ -n "$local_pane_id" ]]; then
    tmux set-option -pu -t "$local_pane_id" @pane_label 2>/dev/null || true
    tmux set-option -gu "@iap_remote_status_${local_pane_id#%}" 2>/dev/null || true
  fi
}

stop_reconnecting() {
  stop=true
}

monitor_parent() {
  while kill -0 "$parent_pid" 2>/dev/null; do
    sleep 2
  done

  kill -TERM -- "-$process_group_id" 2>/dev/null || true
}

finish() {
  if [[ -n "$parent_monitor_pid" ]] && kill -0 "$parent_monitor_pid" 2>/dev/null; then
    kill -TERM "$parent_monitor_pid" 2>/dev/null || true
  fi
  clear_local_pane
  release_lock
}

trap stop_reconnecting INT TERM HUP
trap finish EXIT

acquire_instance
detect_local_pane
mark_local_pane
monitor_parent &
parent_monitor_pid=$!

readonly remote_command="
cd '$remote_workdir' &&
source .bashrc.minkerui >/dev/null 2>&1 &&
(tmux has-session -t '$remote_session' 2>/dev/null || tmux new-session -d -s '$remote_session' 'exec bash -i' >/dev/null 2>&1) &&
tmux set-option -g status-bg colour235 >/dev/null 2>&1 &&
tmux set-option -g status-fg colour250 >/dev/null 2>&1 &&
tmux set-option -g status-left '' >/dev/null 2>&1 &&
tmux set-option -g status-right '' >/dev/null 2>&1 &&
tmux set-option -g history-limit 100000 >/dev/null 2>&1 &&
tmux set-window-option -g window-status-format '#[fg=colour244] #W ' >/dev/null 2>&1 &&
tmux set-window-option -g window-status-current-format '#[fg=colour81,bold] #W ' >/dev/null 2>&1 &&
tmux set-window-option -g aggressive-resize on >/dev/null 2>&1 &&
tmux set-window-option -g mode-mouse on >/dev/null 2>&1 &&
tmux set-option -t '$remote_session' status off >/dev/null 2>&1 &&
exec tmux attach-session -d -t '$remote_session'
"

while [[ "$stop" == false ]]; do
  TERM=xterm-256color ssh \
    -tt \
    -o ConnectTimeout=10 \
    -o ConnectionAttempts=1 \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=2 \
    -o TCPKeepAlive=yes \
    "$remote_user_host" \
    "$remote_command"
  status=$?

  [[ "$stop" == true ]] && break

  printf '\nIAP disconnected (ssh exit %s); reconnecting in %ss. Press Ctrl-C to stop.\n' \
    "$status" "$retry_delay" >&2
  sleep "$retry_delay" &
  wait $!
done

exit "$final_status"

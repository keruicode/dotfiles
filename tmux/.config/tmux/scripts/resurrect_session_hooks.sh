#!/usr/bin/env bash

set -u

mode="${1:-}"
manager_hook='run-shell -b "python3 ~/.config/tmux/scripts/session_manager.py ensure"'

pause_session_ordering() {
    tmux set-hook -gu session-created
    tmux set-hook -gu session-closed

    local session_count pane_count anchor_id anchor_name
    session_count="$(tmux list-sessions -F '#{session_id}' 2>/dev/null | awk 'NF { count++ } END { print count + 0 }')"
    pane_count="$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | awk 'NF { count++ } END { print count + 0 }')"

    # session_manager renames tmux's fresh session "0" to "1-0". Resurrect
    # only removes its bootstrap pane when that session is named exactly "0".
    if [[ "$session_count" == "1" && "$pane_count" == "1" ]]; then
        anchor_id="$(tmux list-sessions -F '#{session_id}' 2>/dev/null | head -n 1)"
        anchor_name="$(tmux display-message -p -t "$anchor_id" '#{session_name}' 2>/dev/null || true)"
        if [[ "$anchor_name" == "0" || "$anchor_name" =~ ^[0-9]+-0$ ]]; then
            tmux rename-session -t "$anchor_id" 0
        fi
    fi
}

resume_session_ordering() {
    tmux set-hook -g session-created "$manager_hook"
    tmux set-hook -g session-closed "$manager_hook"
    python3 "$HOME/.config/tmux/scripts/session_manager.py" ensure >/dev/null 2>&1 || true
}

case "$mode" in
    pre)
        pause_session_ordering
        ;;
    post)
        resume_session_ordering
        ;;
esac

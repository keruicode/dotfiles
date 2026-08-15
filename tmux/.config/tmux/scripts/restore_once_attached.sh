#!/usr/bin/env bash

set -u

marker_option='@dotfiles-resurrect-server-start'
server_start="$(tmux display-message -p '#{start_time}' 2>/dev/null || true)"

[[ -n "$server_start" ]] || exit 0

previous_start="$(tmux show-options -gv "$marker_option" 2>/dev/null || true)"
[[ "$previous_start" != "$server_start" ]] || exit 0

# tmux-resurrect uses switch-client while restoring selection state. Running it
# before a client exists can leave the background restore blocked indefinitely.
client_count="$(tmux list-clients -F '#{client_name}' 2>/dev/null | awk 'NF { count++ } END { print count + 0 }')"
(( client_count > 0 )) || exit 0

pane_count="$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | awk 'NF { count++ } END { print count + 0 }')"
tmux set-option -gq "$marker_option" "$server_start"

# A populated server is already live. This also makes config reloads harmless.
(( pane_count <= 1 )) || exit 0

restore_script="$(tmux show-options -gv @resurrect-restore-script-path 2>/dev/null || true)"
restore_script="${restore_script:-$HOME/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh}"
[[ -x "$restore_script" ]] || exit 0

"$restore_script"

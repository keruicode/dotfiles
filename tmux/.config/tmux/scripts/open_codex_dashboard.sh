#!/usr/bin/env bash
set -u

client_tty="${1:-}"
client_width="${2:-}"
client_height="${3:-}"

if [[ -z "$client_tty" ]]; then
  client_tty="$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)"
fi
if [[ -z "$client_width" || ! "$client_width" =~ ^[0-9]+$ ]]; then
  client_width="$(tmux display-message -p -c "$client_tty" '#{client_width}' 2>/dev/null || printf '96')"
fi
if [[ -z "$client_height" || ! "$client_height" =~ ^[0-9]+$ ]]; then
  client_height="$(tmux display-message -p -c "$client_tty" '#{client_height}' 2>/dev/null || printf '26')"
fi

width=$((client_width * 7 / 10))
(( width < 54 )) && width=54
(( width > 76 )) && width=76
(( width > client_width - 4 )) && width=$((client_width - 4))

height=$((client_height * 2 / 3))
(( height < 14 )) && height=14
(( height > 22 )) && height=22
(( height > client_height - 3 )) && height=$((client_height - 3))

exec tmux display-popup -E -c "$client_tty" -x R -y 1 \
  -w "$width" -h "$height" -b rounded \
  -s 'bg=#282a36,fg=#f8f8f2' -S 'bg=#282a36,fg=#59616d' \
  -T ' Codex Tasks ' \
  "$HOME/.config/tmux/scripts/codex_dashboard.py" popup "$client_tty"

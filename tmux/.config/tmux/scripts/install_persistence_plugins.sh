#!/usr/bin/env bash
set -euo pipefail

plugin_root="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
update=false

if [[ "${1:-}" == "--update" ]]; then
  update=true
elif [[ $# -gt 0 ]]; then
  printf 'usage: %s [--update]\n' "${0##*/}" >&2
  exit 2
fi

install_plugin() {
  local name="$1"
  local repo="$2"
  local target="$plugin_root/$name"

  if [[ -d "$target/.git" ]]; then
    if [[ "$update" == true ]]; then
      if [[ "$name" == tmux-resurrect && -L "$target/scripts/spinner_helpers.sh" ]]; then
        unlink "$target/scripts/spinner_helpers.sh"
        git -C "$target" restore --worktree scripts/spinner_helpers.sh
      fi
      git -C "$target" pull --ff-only
    else
      printf '%s already installed\n' "$name"
    fi
    return
  fi

  if [[ -e "$target" ]]; then
    printf 'refusing to replace non-git path: %s\n' "$target" >&2
    exit 1
  fi

  git clone --depth 1 "$repo" "$target"
}

mkdir -p "$plugin_root"
install_plugin tmux-resurrect https://github.com/tmux-plugins/tmux-resurrect.git
install_plugin tmux-continuum https://github.com/tmux-plugins/tmux-continuum.git

strategy_source="$script_dir/resurrect_foreground_process.sh"
strategy_target="$plugin_root/tmux-resurrect/save_command_strategies/codex_foreground.sh"
activity_source="$script_dir/resurrect_status_activity.sh"
activity_target="$plugin_root/tmux-resurrect/scripts/spinner_helpers.sh"

if [[ -e "$strategy_target" && ! -L "$strategy_target" ]]; then
  printf 'refusing to replace non-symlink strategy: %s\n' "$strategy_target" >&2
  exit 1
fi
ln -sfn "$strategy_source" "$strategy_target"

if [[ -e "$activity_target" && ! -L "$activity_target" ]]; then
  unlink "$activity_target"
fi
ln -sfn "$activity_source" "$activity_target"

printf 'plugins ready in %s\n' "$plugin_root"
printf 'reload with: tmux source-file ~/.tmux.conf\n'

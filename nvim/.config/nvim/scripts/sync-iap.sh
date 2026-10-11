#!/usr/bin/env bash
set -euo pipefail

readonly remote_host="elzd_2023_00026@10.64.201.2"
readonly remote_home="/data1/elpt_2022_00083/kerui"
readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly config_dir="$(cd -- "$script_dir/.." && pwd)"
readonly config_root="$(cd -- "$config_dir/.." && pwd)"
readonly iap_config_dir="$config_root/nvim-iap"

sync_plugins=false
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --plugins) sync_plugins=true ;;
    --dry-run) dry_run=true ;;
    *)
      printf 'usage: %s [--plugins] [--dry-run]\n' "$0" >&2
      exit 2
      ;;
  esac
done

route -n get 10.64.201.2 2>/dev/null | grep -q 'interface: utun'
nc -G 5 -z 10.64.201.2 22

rsync_args=(-az --delete --exclude=.DS_Store --exclude='._*')
if [[ "$dry_run" == true ]]; then
  rsync_args+=(-nvi)
fi

rsync "${rsync_args[@]}" "$config_dir/" "$remote_host:$remote_home/.config/nvim/"
rsync "${rsync_args[@]}" "$iap_config_dir/" "$remote_host:$remote_home/.config/nvim-iap/"

if [[ "$sync_plugins" == true ]]; then
  rsync "${rsync_args[@]}" \
    --exclude='blink.cmp/target/' \
    "$HOME/.local/share/nvim/lazy/" \
    "$remote_host:$remote_home/.local/share/nvim/lazy/"
fi

if [[ "$dry_run" == false ]]; then
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$remote_host" \
    "source '$remote_home/.bashrc.minkerui' >/dev/null 2>&1 && timeout 30 env NVIM_APPNAME=nvim-iap '$remote_home/software/nvim-linux-x86_64-v0.12.2/bin/nvim' --headless '+lua print(\"IAP light Neovim OK: \" .. vim.fn.stdpath(\"config\"))' +qa"
fi

alias c='clear'
#alias ra='ranger'
alias ra='yazi'
alias l='ls -la'
alias lg='lazygit'
alias s='neofetch'

### kitty终端图片命令
alias icat="/Applications/kitty.app/Contents/MacOS/kitty +kitten icat"

alias fp="scp -r mkr@157.0.78.3:~/fly/\*.png ."
alias ft="scp -r mkr@157.0.78.3:~/fly/\*.tif ."

alias zky="ssh elpt_2023_000308@login.earthlab.iap.ac.cn"

alias rsynceps='rsync -rauvzP --rsh=ssh --include="*.eps" --include="*.tif" --include="*/" --exclude="*"'

alias rsynctif='rsync -rauvzP --rsh=ssh --include="*.tif" --include="*/" --exclude="*"'

alias zw="cd '/Users/xiaoxiaotu/Library/Containers/com.tencent.xinWeChat/Data/Library/Application Support/com.tencent.xinWeChat/2.0b4.0.9/f1ebfd663f389c95d453f1d939acb93d/Message/MessageTemp/db2faa25031350404b3c942271e33735/File'"
alias bed="scp -r mkr@157.0.78.3:~/fly/\* ."
alias bed10="scp -r mkr@10.255.255.5:~/fly/\* ."

#alias fp="scp -r lxl@157.0.78.3:~/mkr/fly/\*.png ."
#alias ft="scp -r lxl@157.0.78.3:~/mkr/fly/\*.tif ."
#alias bed="scp -r lxl@157.0.78.3:~/mkr/fly/\* ."
#
alias vim='nvim'

# Keep plain `codex` in yolo mode, but do not duplicate an explicit flag from
# tmux-resurrect or a manually entered resume command.
unalias codex 2>/dev/null
codex() {
  local -a args
  local arg
  local has_yolo=0

  for arg in "$@"; do
    case "$arg" in
      --yolo|--dangerously-bypass-approvals-and-sandbox)
        if (( ! has_yolo )); then
          args+=("$arg")
          has_yolo=1
        fi
        ;;
      *) args+=("$arg") ;;
    esac
  done

  (( has_yolo )) || args=(--yolo "${args[@]}")
  command codex "${args[@]}"
}

# Short resume command used in Codex handoff files.
alias code='codex'

alias op='open ./'
alias storage-eject='~/.config/tmux/scripts/external_workspace.py eject'
alias storage-restore='~/.config/tmux/scripts/external_workspace.py restore'
alias tmux-save-all='~/.config/tmux/scripts/tmux_snapshot.py checkpoint manual'
alias tmux-snapshots='~/.config/tmux/scripts/tmux_snapshot.py list'
alias codex-panel='~/.config/tmux/scripts/open_codex_dashboard.sh'
alias codex-status='~/.config/tmux/scripts/codex_dashboard.py status'

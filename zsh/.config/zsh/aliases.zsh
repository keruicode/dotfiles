# Do not let a non-interactive launcher disable colours in interactive TUIs.
# TMUX identifies local tmux panes even when TERM_PROGRAM was not inherited.
unset NO_COLOR
export CLICOLOR=1
if [[ -n ${TMUX-} || ${TERM_PROGRAM-} == WezTerm ]]; then
  export COLORTERM=truecolor
fi

# Resolve the symlink so the helper is available before a new Stow deployment.
source "${${(%):-%N}:A:h}/terminal.zsh"

# A nested zsh inherits Conda state but not Conda's left-side prompt prefix.
# Reactivate the same environment once to refresh PROMPT without adding a level.
if [[ ${YAZI_RESTORE_CONDA_PROMPT-} == 1 && -n ${CONDA_DEFAULT_ENV-} ]]; then
  autoload -Uz add-zsh-hook
  _yazi_restore_conda_prompt_once() {
    add-zsh-hook -d precmd _yazi_restore_conda_prompt_once
    if (( ${+functions[conda]} )); then
      conda activate "$CONDA_DEFAULT_ENV" >/dev/null 2>&1
    fi
    unset YAZI_RESTORE_CONDA_PROMPT
    unfunction _yazi_restore_conda_prompt_once 2>/dev/null
  }
  add-zsh-hook precmd _yazi_restore_conda_prompt_once
fi

alias c='clear'
#alias ra='ranger'
alias ra='yazi'
alias l='ls -la'
alias lg='lazygit'
alias s='neofetch'

### kitty终端图片命令
alias icat="/Applications/kitty.app/Contents/MacOS/kitty +kitten icat"

# macOS visual diff: `kd old-file new-file` opens Kaleidoscope.
alias kd='/Applications/Kaleidoscope.app/Contents/MacOS/ksdiff'

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

# Keep plain `codex` in yolo mode and use the lean CLI profile. Do not add the
# profile to plugin/help/version commands, because those management commands do
# not accept `--profile`.
unalias codex 2>/dev/null
codex() {
  local -a args
  local arg
  local has_yolo=0
  local has_profile=0
  local is_management_command=0

  for arg in "$@"; do
    case "$arg" in
      --yolo|--dangerously-bypass-approvals-and-sandbox)
        if (( ! has_yolo )); then
          args+=("$arg")
          has_yolo=1
        fi
        ;;
      -p|--profile|--profile=*)
        has_profile=1
        args+=("$arg")
        ;;
      plugin|help|version|--help|-h|--version|-V)
        is_management_command=1
        args+=("$arg")
        ;;
      *) args+=("$arg") ;;
    esac
  done

  (( has_yolo )) || args=(--yolo "${args[@]}")
  if (( has_profile || is_management_command )); then
    command codex "${args[@]}"
  else
    command codex -p cli-lean "${args[@]}"
  fi
}

# Short resume command used in Codex handoff files.
alias code='codex'

alias op='open ./'
alias storage-eject='python3 ~/.config/tmux/scripts/external_workspaces_all.py eject'
alias storage-restore='python3 ~/.config/tmux/scripts/external_workspaces_all.py restore'
alias tmux-save-all='~/.config/tmux/scripts/tmux_snapshot.py checkpoint manual'
alias tmux-snapshots='~/.config/tmux/scripts/tmux_snapshot.py list'
alias codex-panel='~/.config/tmux/scripts/open_codex_dashboard.sh'
alias codex-status='~/.config/tmux/scripts/codex_dashboard.py status'

# The stock `_zip` completion treats `unzip -x` arguments as free-form glob
# patterns.  Complete actual archive entries instead when the archive precedes
# `-x`, which is the normal Info-ZIP invocation order.
_unzip_exclude_entries() {
  local archive='' word
  local -i index

  for (( index = 2; index < CURRENT; index++ )); do
    word=${words[index]}
    case $word in
      -x|--exclude) break ;;
      -d|-P) (( index++ )) ;;
      --) ;;
      -*) ;;
      *)
        archive=$word
        break
        ;;
    esac
  done

  if [[ -z $archive || ! -f $archive ]]; then
    _files -g '*(#i).zip'
    return
  fi

  local -a entries
  entries=( "${(@f)$(command unzip -Z1 -- "$archive" 2>/dev/null)}" )
  (( $#entries )) || return 1
  _wanted archive-entries expl 'entry in archive' compadd -Q -S '' -- $entries
}

_unzip_with_entries() {
  local -i exclude_index=${words[(I)-x]}
  (( ! exclude_index )) && exclude_index=${words[(I)--exclude]}
  if (( exclude_index && CURRENT > exclude_index )); then
    _unzip_exclude_entries
  else
    _zip
  fi
}

compdef _unzip_with_entries unzip

# Run only at the shell prompt, after a foreground TUI has returned.
_dotfiles_prompt_terminal_reset() {
  [[ -o interactive && -n ${TMUX-} && -t 1 ]] || return 0
  stty -ixon -ixoff 2>/dev/null
  local alternate=''
  if [[ -n ${TMUX_PANE-} ]]; then
    alternate=$(command tmux display-message -p -t "$TMUX_PANE" '#{alternate_on}' 2>/dev/null)
  fi
  # Repeating 1049l on the normal screen restores an old cursor in tmux and
  # overwrites command output. Only send it when the alternate screen is active.
  [[ $alternate == 1 ]] && printf '\033[?1049l'
  printf '\033[?1000l\033[?1002l\033[?1003l\033[?1005l\033[?1006l\033[?1015l\033[?1004l\033[?25h'
}
if [[ -o interactive && -n ${TMUX-} ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _dotfiles_prompt_terminal_reset
fi

if gpg_tty="$(tty 2>/dev/null)"; then
  export GPG_TTY="$gpg_tty"
fi
unset gpg_tty

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

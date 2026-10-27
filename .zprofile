if [[ -n "${HOMEBREW_PREFIX:-}" && -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
  eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"
fi

if command -v mkcert >/dev/null 2>&1; then
  root_ca="$(mkcert -CAROOT)/rootCA.pem"
  if [[ -f "$root_ca" ]]; then
    export NODE_EXTRA_CA_CERTS="$root_ca"
  fi
  unset root_ca
fi

if [[ -f "$HOME/.orbstack/shell/init2.sh" ]]; then
  source "$HOME/.orbstack/shell/init2.sh" 2>/dev/null || :
fi

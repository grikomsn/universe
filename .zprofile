if [[ -n "${HOMEBREW_PREFIX:-}" && -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
  eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"
fi

if command -v mkcert >/dev/null 2>&1; then
  export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"
fi

if [[ -f "$HOME/.orbstack/shell/init2.sh" ]]; then
  source "$HOME/.orbstack/shell/init2.sh" 2>/dev/null || :
fi

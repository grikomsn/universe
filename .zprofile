if [[ -n "${HOMEBREW_PREFIX:-}" && -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
  eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"
fi

# Where `mkcert -CAROOT` resolves to ($CAROOT if set, else the macOS or XDG
# data dir), checked directly to skip the subprocess.
if [[ -n "${CAROOT:-}" ]]; then
  root_cas=("$CAROOT/rootCA.pem")
else
  root_cas=("$HOME/Library/Application Support/mkcert/rootCA.pem" ${XDG_DATA_HOME:+"$XDG_DATA_HOME/mkcert/rootCA.pem"} "$HOME/.local/share/mkcert/rootCA.pem")
fi
for root_ca in "${root_cas[@]}"; do
  if [[ -f "$root_ca" ]]; then
    export NODE_EXTRA_CA_CERTS="$root_ca"
    break
  fi
done
unset root_ca root_cas

if [[ -f "$HOME/.orbstack/shell/init2.sh" ]]; then
  source "$HOME/.orbstack/shell/init2.sh" 2>/dev/null || :
fi

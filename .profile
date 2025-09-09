# 00-core

export ADBLOCK=1
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export DISABLE_OPENCOLLECTIVE=1
export GPG_TTY=$TTY # https://stackoverflow.com/a/57591830/4273667
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
export PATH=$HOME/.local/bin:$PATH

# 01-brew

ARCH_NAME="$(uname -m)"
if [ "${ARCH_NAME}" = "arm64" ]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi

# https://github.com/orgs/Homebrew/discussions/4412#discussioncomment-8651316
if [ -d "${BREW_PREFIX}" ]; then
  export HOMEBREW_CELLAR="${BREW_PREFIX}/Cellar"
  export HOMEBREW_REPOSITORY="${BREW_PREFIX}/homebrew"
  export PATH="${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:$PATH"
  export MANPATH="${BREW_PREFIX}/share/man:$MANPATH"
  export INFOPATH="${BREW_PREFIX}/share/info:$INFOPATH"
  $HOMEBREW_PREFIX/bin/brew shellenv | source

  # bin extras
  export PATH="${BREW_PREFIX}/opt/curl/bin:$PATH"
fi

# 02-profile

# bun
if [ -d "$HOME/.bun" ]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

# chatwise
if [ -d "/Applications/ChatWise.app" ]; then
  export CHATWISE_INSTALL="/Applications/ChatWise.app/Contents/MacOS"
  export PATH="$CHATWISE_INSTALL:$PATH"
fi

# deno
if [ -d "$HOME/.deno" ]; then
  export DENO_INSTALL="$HOME/.deno"
  export PATH="$DENO_INSTALL/bin:$PATH"
fi

# fnm
eval $(fnm env)

# fzf
eval $(fzf --fish)

# go
if [ -d "$HOME/.go" ]; then
  export GOPATH="$HOME/.go"
  export PATH="$GOPATH/bin:$PATH"
fi

# lmstudio
if [ -d "$HOME/.lmstudio" ]; then
  export LM_STUDIO_INSTALL="$HOME/.lmstudio"
  export PATH="$LM_STUDIO_INSTALL/bin:$PATH"
fi

# mkcert
export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"

# orbstack
if [ -f "$HOME/.orbstack/shell/init2.fish" ]; then
  source "$HOME/.orbstack/shell/init2.fish" 2>/dev/null || :
fi

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# rust
if [ -d "$HOME/.cargo" ]; then
  export RUST_INSTALL="$HOME/.cargo"
  export PATH="$RUST_INSTALL/bin:$PATH"
fi

# yarn
export PATH="$HOME/.yarn/bin:$PATH"

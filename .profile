export ADBLOCK=1
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export DISABLE_OPENCOLLECTIVE=1
export GPG_TTY=$TTY # https://stackoverflow.com/a/57591830/4273667
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
export PATH=$HOME/.local/bin:$PATH

eval $(ssh-agent)

# brew (darwin only)
# https://github.com/orgs/Homebrew/discussions/4412#discussioncomment-8651316
if [[ "$(uname -o)" == "Darwin" ]] && [[ -n "$HOMEBREW_PREFIX" ]]; then
    source "$HOMEBREW_PREFIX/bin/brew" shellenv

    export PATH="$HOMEBREW_PREFIX/opt/curl/bin:$PATH"
    export PATH="$HOMEBREW_PREFIX/opt/dotnet/libexec:$PATH"
fi

# bun
if [ -d "$HOME/.bun" ]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

# deno
if [ -d "$HOME/.deno" ]; then
  export DENO_INSTALL="$HOME/.deno"
  export PATH="$DENO_INSTALL/bin:$PATH"
fi

# filen-cli
if [ -d "$HOME/.filen-cli" ]; then
  export FILEN_CLI_INSTALL="$HOME/.filen-cli"
  export PATH="$FILEN_CLI_INSTALL/bin:$PATH"
fi

# fnm
if which fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
else
    if [ -d "$HOME/.fnm" ]; then
      export FNM_PATH="$HOME/.fnm"
    elif [ -n "$XDG_DATA_HOME" ]; then
      export FNM_PATH="$XDG_DATA_HOME/fnm"
    elif [[ "$(uname -o)" == "Darwin" ]]; then
      export FNM_PATH="$HOME/Library/Application Support/fnm"
    else
      export FNM_PATH="$HOME/.local/share/fnm"
    fi
    export PATH="$FNM_PATH:$PATH"
    if which fnm >/dev/null 2>&1; then
      eval "$(fnm env --use-on-cd)"
    fi
fi

# fzf
if which fzf >/dev/null 2>&1; then
  if [[ -n "$BASH_VERSION" ]]; then
    eval "$(fzf --bash)"
  elif [[ -n "$FISH_VERSION" ]]; then
    eval "$(fzf --fish)"
  elif [[ -n "$ZSH_VERSION" ]]; then
    eval "$(fzf --zsh)"
  fi
fi

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
if which mkcert >/dev/null 2>&1; then
  export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"
fi

# opencode
if [ -d "$HOME/.opencode" ]; then
  export OPENCODE_INSTALL="$HOME/.opencode"
  export PATH="$OPENCODE_INSTALL/bin:$PATH"
fi

# orbstack
if [ -f "$HOME/.orbstack/shell/init2.sh" ]; then
  source "$HOME/.orbstack/shell/init2.sh" 2>/dev/null || :
fi

# pnpm
export PNPM_HOME="$HOME/.pnpm"
export PATH="$PNPM_HOME:$PATH"

# rust
if [ -d "$HOME/.cargo" ]; then
    source "$HOME/.cargo/env"
fi

# yarn
export YARN_INSTALL="$HOME/.yarn"
export PATH="$YARN_INSTALL/bin:$PATH"

export ADBLOCK=1
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export DISABLE_OPENCOLLECTIVE=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

path_prepend() {
  [ -d "$1" ] || return
  if [ -z "${PATH:-}" ]; then
    PATH="$1"
    return
  fi
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

path_prepend "/usr/local/sbin"
path_prepend "/usr/local/bin"
path_prepend "$HOME/.local/bin"

if [ -x /opt/homebrew/bin/brew ]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
elif [ -x /usr/local/bin/brew ]; then
  export HOMEBREW_PREFIX="/usr/local"
fi

if [ -n "${HOMEBREW_PREFIX:-}" ]; then
  path_prepend "$HOMEBREW_PREFIX/bin"
  path_prepend "$HOMEBREW_PREFIX/sbin"
  path_prepend "$HOMEBREW_PREFIX/opt/curl/bin"
  path_prepend "$HOMEBREW_PREFIX/opt/dotnet/libexec"
fi

if [ -d "$HOME/.bun" ]; then
  export BUN_INSTALL="$HOME/.bun"
  path_prepend "$BUN_INSTALL/bin"
fi

if [ -d "$HOME/.deno" ]; then
  export DENO_INSTALL="$HOME/.deno"
  path_prepend "$DENO_INSTALL/bin"
fi

if [ -d "$HOME/.filen-cli" ]; then
  export FILEN_CLI_INSTALL="$HOME/.filen-cli"
  path_prepend "$FILEN_CLI_INSTALL/bin"
fi

if [ -d "$HOME/.fnm" ]; then
  export FNM_PATH="$HOME/.fnm"
elif [ -n "${XDG_DATA_HOME:-}" ] && [ -d "$XDG_DATA_HOME/fnm" ]; then
  export FNM_PATH="$XDG_DATA_HOME/fnm"
elif [ -d "$HOME/Library/Application Support/fnm" ]; then
  export FNM_PATH="$HOME/Library/Application Support/fnm"
elif [ -d "$HOME/.local/share/fnm" ]; then
  export FNM_PATH="$HOME/.local/share/fnm"
fi
if [ -n "${FNM_PATH:-}" ]; then
  path_prepend "$FNM_PATH"
fi

export GOPATH="$HOME/.go"
path_prepend "$GOPATH/bin"

if [ -d "$HOME/.lmstudio" ]; then
  export LM_STUDIO_INSTALL="$HOME/.lmstudio"
  path_prepend "$LM_STUDIO_INSTALL/bin"
fi

if [ -d "$HOME/.opencode" ]; then
  export OPENCODE_INSTALL="$HOME/.opencode"
  path_prepend "$OPENCODE_INSTALL/bin"
fi

if [ -d "$HOME/Library" ]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.pnpm"
fi
path_prepend "$PNPM_HOME"

path_prepend "$HOME/.qmk_toolchains/bin"
path_prepend "$HOME/.cargo/bin"

export YARN_INSTALL="$HOME/.yarn"
path_prepend "$YARN_INSTALL/bin"

export PATH
unset -f path_prepend 2>/dev/null || unset path_prepend

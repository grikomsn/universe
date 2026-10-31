#!/usr/bin/env bash

set -euo pipefail

# globals.sh - idempotent cross-platform language-toolchain globals, read from
# the Brewfile's `npm`, `go`, and `uv` entries. Unlike `brew bundle`, this
# also upgrades already-installed globals and runs on Linux.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_step() {
  local name="$1"
  shift
  echo "== $name"
  "$@" || echo "warn: $name step failed; continuing" >&2
}

entries() {
  bash "$script_dir/brewfile-entries.sh" "$1"
}

# bootstrap runs in a non-login bash that never sourced ~/.profile; match its
# GOPATH so go tools don't land in the unused default ~/go.
export GOPATH="${GOPATH:-$HOME/.go}"

# --- node (fnm) ---
# Install globals into an fnm-managed node: a distro node (e.g. Fedora's
# /usr/bin/npm) has a root-owned global prefix, so `npm -g` would fail.
for fnm_dir in "$HOME/.local/share/fnm" "$HOME/Library/Application Support/fnm" "$HOME/.fnm"; do
  [[ -x "$fnm_dir/fnm" ]] && PATH="$fnm_dir:$PATH"
done
if command -v fnm >/dev/null; then
  run_step "fnm lts" fnm install --lts
  run_step "fnm default" fnm default lts-latest
  eval "$(fnm env --shell bash)"
fi

# --- npm globals ---
if command -v npm >/dev/null; then
  npm_pkgs=()
  while IFS= read -r pkg; do
    npm_pkgs+=("$pkg@latest")
  done < <(entries npm)
  # npm 12 blocks dependency install scripts by default; these packages need
  # their postinstall to link the native binary.
  run_step "npm globals" npm install -g --allow-scripts=agent-browser,agent-desktop "${npm_pkgs[@]}"
  # agent-browser drives its own Chrome for Testing; fetch it if missing. On
  # Linux, --with-deps also installs Chrome's system libraries/fonts via sudo.
  if command -v agent-browser >/dev/null; then
    agent_browser_args=(install)
    [[ "$(uname -s)" == "Linux" ]] && agent_browser_args+=(--with-deps)
    run_step "agent-browser chrome" agent-browser "${agent_browser_args[@]}"
  fi
else
  echo "npm not found; skipping npm globals" >&2
fi

# --- go tools ---
if command -v go >/dev/null; then
  while IFS= read -r pkg; do
    # auto: distro Go (e.g. Fedora's GOTOOLCHAIN=local) may be older than
    # what @latest tools require; let go fetch the toolchain it needs.
    run_step "go $pkg" env GOTOOLCHAIN=auto go install "$pkg@latest"
  done < <(entries go)
else
  echo "go not found; skipping go tools" >&2
fi

# --- uv tools ---
# marker-pdf[full] pulls CUDA/cuDNN wheels (~10 GB) on Linux; on GPU-less
# headless boxes consider skipping it: SKIP_MARKER_PDF=1 bash globals.sh
if command -v uv >/dev/null; then
  while IFS= read -r pkg; do
    if [[ "$pkg" == marker-pdf* && "${SKIP_MARKER_PDF:-0}" == "1" ]]; then
      echo "== uv $pkg skipped (SKIP_MARKER_PDF=1)"
      continue
    fi
    run_step "uv $pkg" uv tool install --upgrade "$pkg"
  done < <(entries uv)
else
  echo "uv not found; skipping uv tools" >&2
fi

# --- gh extensions (Ghfile; brew bundle cannot express them) ---
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  installed_extensions="$(gh extension list 2>/dev/null || true)"
  while IFS= read -r extension; do
    if [[ "$installed_extensions" == *"$extension"* ]]; then
      run_step "gh $extension" gh extension upgrade "${extension#*/gh-}"
    else
      run_step "gh $extension" gh extension install "$extension"
    fi
  done < <(grep -vE '^[[:space:]]*(#|$)' "$script_dir/../Ghfile")
else
  echo "gh not found or not logged in; skipping gh extensions" >&2
fi

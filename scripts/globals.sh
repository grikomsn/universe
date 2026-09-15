#!/usr/bin/env bash

set -euo pipefail

# globals.sh - idempotent cross-platform language-toolchain globals.
# bash twin of .config/fish/functions/node-update-globals.fish, plus the
# Brewfile's `go` and `uv` entries.

run_step() {
  local name="$1"
  shift
  echo "== $name"
  "$@" || echo "warn: $name step failed; continuing" >&2
}

# --- npm globals (Brewfile `npm` entries) ---
if command -v npm >/dev/null; then
  npm_pkgs=(fish-lsp neovim prettier serve tsx turbo vercel)
  run_step "npm corepack" npm install -g corepack@latest
  run_step "npm globals" npm install -g "${npm_pkgs[@]}"
else
  echo "npm not found; skipping npm globals" >&2
fi

# --- go tools (Brewfile `go` entries) ---
if command -v go >/dev/null; then
  run_step "go goimports" go install golang.org/x/tools/cmd/goimports@latest
  run_step "go gopls" go install golang.org/x/tools/gopls@latest
  run_step "go staticcheck" go install honnef.co/go/tools/cmd/staticcheck@latest
else
  echo "go not found; skipping go tools" >&2
fi

# --- uv tools (Brewfile `uv` entries) ---
# marker-pdf[full] pulls CUDA/cuDNN wheels (~10 GB) on Linux; on GPU-less
# headless boxes consider skipping it: SKIP_MARKER_PDF=1 bash globals.sh
if command -v uv >/dev/null; then
  if [[ "${SKIP_MARKER_PDF:-0}" != "1" ]]; then
    run_step "uv marker-pdf" uv tool install --upgrade "marker-pdf[full]"
  else
    echo "== uv marker-pdf skipped (SKIP_MARKER_PDF=1)"
  fi
  run_step "uv markitdown" uv tool install --upgrade "markitdown[all]"
  run_step "uv streamlit" uv tool install --upgrade streamlit
else
  echo "uv not found; skipping uv tools" >&2
fi

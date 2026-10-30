#!/usr/bin/env bash

set -euo pipefail

# completions.sh - regenerate fish completions for installed CLIs into the
# lnk-managed fish config. The output is gitignored: it is large, churns on
# every tool update, and is reproducible from the tools themselves.
# acli.fish stays tracked because acli no longer ships a completion command.

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dir="$repo/.config/fish/completions"
mkdir -p "$dir"

generate() {
  local name="$1"
  shift
  command -v "$1" >/dev/null || return 0
  if "$@" >"$dir/$name.fish.tmp" 2>/dev/null && [[ -s "$dir/$name.fish.tmp" ]]; then
    mv "$dir/$name.fish.tmp" "$dir/$name.fish"
    echo "generated $name.fish"
  else
    rm -f "$dir/$name.fish.tmp"
    echo "warn: could not generate $name.fish" >&2
  fi
}

# bun picks the script from $SHELL, which is not fish when run from bash/zsh.
if command -v bun >/dev/null; then
  generate bun env SHELL=fish bun completions
fi
generate deno deno completions fish
# gh is everywhere; only generate when the extension itself is installed.
# (Captured first: `| grep -q` would SIGPIPE gh and fail under pipefail.)
gh_extensions="$(gh extension list 2>/dev/null || true)"
if [[ "$gh_extensions" == *gh-pr-review* ]]; then
  generate gh-pr-review gh pr-review completion fish
fi
generate lnk lnk completion fish
generate rex rex completion fish
generate uv uv generate-shell-completion fish

#!/usr/bin/env bash

set -euo pipefail

# brewfile-entries.sh - print the names of one Brewfile entry type, one per
# line (e.g. `vscode`, `npm`, `go`, `uv`). The Brewfile is the single source
# of truth for editor extensions and language-toolchain globals.

type="${1:?usage: $0 <entry-type>}"
repo_brewfile="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Brewfile"

if [[ -f "$repo_brewfile" ]]; then
  brewfile_data="$(cat "$repo_brewfile")"
else
  brewfile_data="$(curl -fsSL https://universe.nibras.co/Brewfile)"
fi

printf '%s\n' "$brewfile_data" | awk -v type="$type" '$1 == type { gsub(/"/, "", $2); print $2 }'

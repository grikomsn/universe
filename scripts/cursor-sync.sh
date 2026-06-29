#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_brewfile="$script_dir/../Brewfile"

extension_source() {
  if [[ -f "$repo_brewfile" ]]; then
    cat "$repo_brewfile"
  else
    curl -fsSL https://universe.nibras.co/Brewfile
  fi
}

EXTENSIONS=()
extension_data="$(extension_source)"
while IFS= read -r extension; do
  EXTENSIONS+=("$extension")
done < <(printf '%s\n' "$extension_data" | awk '/^vscode / { gsub(/"/, "", $2); print $2 }')
if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
  echo "No VS Code extensions found in the Brewfile." >&2
  exit 1
fi

sync_editor() {
  local editor="$1"
  local extension
  local installed_extensions=()
  local installed_data

  command -v "$editor" >/dev/null 2>&1 || return

  installed_data="$("$editor" --list-extensions)"
  while IFS= read -r extension; do
    [[ -n "$extension" ]] || continue
    installed_extensions+=("$extension")
  done <<<"$installed_data"

  for extension in "${EXTENSIONS[@]}"; do
    if ! printf '%s\n' "${installed_extensions[@]}" | grep -qx "$extension"; then
      "$editor" --install-extension "$extension"
    fi
  done

  for extension in "${installed_extensions[@]}"; do
    if ! printf '%s\n' "${EXTENSIONS[@]}" | grep -qx "$extension"; then
      "$editor" --uninstall-extension "$extension"
    fi
  done
}

sync_editor cursor
sync_editor code

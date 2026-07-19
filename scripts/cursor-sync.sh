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
FAILED_EXTENSION_OPERATIONS=()
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
    if ! printf '%s\n' "${installed_extensions[@]}" | grep -Fqx -- "$extension"; then
      if ! "$editor" --install-extension "$extension"; then
        FAILED_EXTENSION_OPERATIONS+=("$editor install $extension")
      fi
    fi
  done

  for extension in "${installed_extensions[@]}"; do
    if ! printf '%s\n' "${EXTENSIONS[@]}" | grep -Fqx -- "$extension"; then
      if ! "$editor" --uninstall-extension "$extension"; then
        FAILED_EXTENSION_OPERATIONS+=("$editor uninstall $extension")
      fi
    fi
  done
}

sync_editor cursor
sync_editor code

if [[ ${#FAILED_EXTENSION_OPERATIONS[@]} -gt 0 ]]; then
  echo "Extension operations failed:" >&2
  printf '  %s\n' "${FAILED_EXTENSION_OPERATIONS[@]}" >&2
  exit 1
fi

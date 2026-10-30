#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EXTENSIONS=()
while IFS= read -r extension; do
  EXTENSIONS+=("$extension")
done < <(bash "$script_dir/brewfile-entries.sh" vscode)
if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
  echo "No VS Code extensions found in the Brewfile." >&2
  exit 1
fi

editor="${1:-code}"
if [[ "$editor" != "code" && "$editor" != "cursor" ]]; then
  echo "Usage: $0 [code|cursor]" >&2
  exit 1
fi

if ! command -v "$editor" >/dev/null 2>&1; then
  if [[ $# -eq 0 && "$editor" == "code" ]] && command -v cursor >/dev/null 2>&1; then
    editor="cursor"
  else
    echo "$editor is not installed." >&2
    exit 1
  fi
fi

INSTALLED_EXTENSIONS=()
installed_data="$("$editor" --list-extensions)"
while IFS= read -r extension; do
  [[ -n "$extension" ]] || continue
  INSTALLED_EXTENSIONS+=("$extension")
done <<<"$installed_data"

echo "=== Extensions in source but NOT installed ==="
NOT_INSTALLED=()
for extension in "${EXTENSIONS[@]}"; do
  if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -Fqx -- "$extension"; then
    NOT_INSTALLED+=("$extension")
  fi
done

if [[ ${#NOT_INSTALLED[@]} -eq 0 ]]; then
  echo "(none)"
else
  printf '%s\n' "${NOT_INSTALLED[@]}"
fi

echo
echo "=== Extensions installed but NOT in source ==="
EXTRA_INSTALLED=()
for extension in "${INSTALLED_EXTENSIONS[@]}"; do
  if ! printf '%s\n' "${EXTENSIONS[@]}" | grep -Fqx -- "$extension"; then
    EXTRA_INSTALLED+=("$extension")
  fi
done

if [[ ${#EXTRA_INSTALLED[@]} -eq 0 ]]; then
  echo "(none)"
else
  printf '%s\n' "${EXTRA_INSTALLED[@]}"
fi

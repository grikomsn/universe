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

bash "$script_dir/vscode-migrate.sh"

# early stub directories
DATA_DIR_VALUES=(
  "Antigravity"
  "Cursor"
  "Devin"
  "Kiro"
  "Windsurf"
)

# Define the VS Code data directory based on platform.
if [[ "$(uname -s)" == "Darwin" ]]; then
  VSCODE_DATA_DIR="$HOME/Library/Application Support/Code"
else
  VSCODE_DATA_DIR="$HOME/.config/Code"
fi

# Create the canonical VS Code user data directory and config stubs.
mkdir -p "$VSCODE_DATA_DIR/User"

if [[ ! -f "$VSCODE_DATA_DIR/User/settings.json" ]]; then
  echo '{}' >"$VSCODE_DATA_DIR/User/settings.json"
fi
if [[ ! -f "$VSCODE_DATA_DIR/User/keybindings.json" ]]; then
  echo '[]' >"$VSCODE_DATA_DIR/User/keybindings.json"
fi

# define targets to symlink (not everything will be symlink'd)
USER_SYMLINK_TARGETS=(
  "keybindings.json"
  "settings.json"
)

# iterate on target data directories
for DATA_DIR_VALUE in "${DATA_DIR_VALUES[@]}"; do
  if [[ "$(uname -s)" == "Darwin" ]]; then
    TARGET_DATA_DIR="$HOME/Library/Application Support/$DATA_DIR_VALUE"
  else
    TARGET_DATA_DIR="$HOME/.config/$DATA_DIR_VALUE"
  fi

  mkdir -p "$TARGET_DATA_DIR/User"

  # iterate on user symlink targets
  for USER_SYMLINK_TARGET in "${USER_SYMLINK_TARGETS[@]}"; do
    ln -sf "$VSCODE_DATA_DIR/User/$USER_SYMLINK_TARGET" "$TARGET_DATA_DIR/User/$USER_SYMLINK_TARGET"
  done
done

# Install only non-existing extensions via `code`.
if command -v code &>/dev/null; then
  INSTALLED_EXTENSIONS=()
  installed_data="$(code --list-extensions)"
  while IFS= read -r extension; do
    [[ -n "$extension" ]] || continue
    INSTALLED_EXTENSIONS+=("$extension")
  done <<<"$installed_data"
  for extension in "${EXTENSIONS[@]}"; do
    if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -Fqx -- "$extension"; then
      if ! code --install-extension "$extension"; then
        FAILED_EXTENSION_OPERATIONS+=("code install $extension")
      fi
    fi
  done
fi

# Install only non-existing extensions via `cursor`.
if command -v cursor &>/dev/null; then
  INSTALLED_EXTENSIONS=()
  installed_data="$(cursor --list-extensions)"
  while IFS= read -r extension; do
    [[ -n "$extension" ]] || continue
    INSTALLED_EXTENSIONS+=("$extension")
  done <<<"$installed_data"
  for extension in "${EXTENSIONS[@]}"; do
    if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -Fqx -- "$extension"; then
      if ! cursor --install-extension "$extension"; then
        FAILED_EXTENSION_OPERATIONS+=("cursor install $extension")
      fi
    fi
  done
fi

if [[ ${#FAILED_EXTENSION_OPERATIONS[@]} -gt 0 ]]; then
  echo "Extension operations failed:" >&2
  printf '  %s\n' "${FAILED_EXTENSION_OPERATIONS[@]}" >&2
  exit 1
fi

#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Install missing (and prune extra) extensions via vscode-sync.
exec bash "$script_dir/vscode-sync.sh"

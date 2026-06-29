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

# dotdir values for other vscode forks
DOTDIR_VALUES=(
  ".antigravity"
  ".cursor-nightly"
  ".kiro"
  ".vscode"
  ".vscode-oss"
  ".windsurf"
)

# symlink cursor dotdir to others
mkdir -p "$HOME/.cursor"
for DOTDIR_VALUE in "${DOTDIR_VALUES[@]}"; do
  ln -sf "$HOME/.cursor" "$HOME/$DOTDIR_VALUE"
done

# early stub directories
DATA_DIR_VALUES=(
  "Antigravity"
  "Code"
  "Kiro"
  "Windsurf"
)

# define CURSOR_DATA_DIR based on platform
if [[ "$(uname -o)" == "Darwin" ]]; then
  CURSOR_DATA_DIR="$HOME/Library/Application Support/Cursor"
else
  CURSOR_DATA_DIR="$HOME/.config/Cursor"
fi

# early stub cursor data directory
mkdir -p "$CURSOR_DATA_DIR/User"

# early stub json configs
if [ ! -f "$CURSOR_DATA_DIR/User/settings.json" ]; then
  echo '{}' >"$CURSOR_DATA_DIR/User/settings.json"
fi
if [ ! -f "$CURSOR_DATA_DIR/User/keybindings.json" ]; then
  echo '[]' >"$CURSOR_DATA_DIR/User/keybindings.json"
fi

# define targets to symlink (not everything will be symlink'd)
USER_SYMLINK_TARGETS=(
  "keybindings.json"
  "settings.json"
)

# iterate on target data directories
for DATA_DIR_VALUE in "${DATA_DIR_VALUES[@]}"; do
  if [[ "$(uname -o)" == "Darwin" ]]; then
    TARGET_DATA_DIR="$HOME/Library/Application Support/$DATA_DIR_VALUE"
  else
    TARGET_DATA_DIR="$HOME/.config/$DATA_DIR_VALUE"
  fi

  mkdir -p "$TARGET_DATA_DIR/User"

  # iterate on user symlink targets
  for USER_SYMLINK_TARGET in "${USER_SYMLINK_TARGETS[@]}"; do
    ln -sf "$CURSOR_DATA_DIR/User/$USER_SYMLINK_TARGET" "$TARGET_DATA_DIR/User/$USER_SYMLINK_TARGET"
  done
done

# install only non-existing extensions via `cursor`
if command -v cursor &>/dev/null; then
  INSTALLED_EXTENSIONS=()
  installed_data="$(cursor --list-extensions)"
  while IFS= read -r extension; do
    [[ -n "$extension" ]] || continue
    INSTALLED_EXTENSIONS+=("$extension")
  done <<<"$installed_data"
  for extension in "${EXTENSIONS[@]}"; do
    if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -qx "$extension"; then
      cursor --install-extension "$extension"
    fi
  done
fi

# install only non-existing extensions via `code`
if command -v code &>/dev/null; then
  INSTALLED_EXTENSIONS=()
  installed_data="$(code --list-extensions)"
  while IFS= read -r extension; do
    [[ -n "$extension" ]] || continue
    INSTALLED_EXTENSIONS+=("$extension")
  done <<<"$installed_data"
  for extension in "${EXTENSIONS[@]}"; do
    if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -qx "$extension"; then
      code --install-extension "$extension"
    fi
  done
fi

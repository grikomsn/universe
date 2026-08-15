#!/usr/bin/env bash

set -euo pipefail

VSCODE_DOTDIR="$HOME/.vscode"
VSCODE_SHARED_DOTDIR="$HOME/.vscode-shared"
MIGRATION_TIMESTAMP="${VSCODE_MIGRATION_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"

DOTDIR_LINKS=(
  ".antigravity"
  ".cursor"
  ".cursor-nightly"
  ".devin"
  ".kiro"
  ".vscode-oss"
  ".windsurf"
)

backup_path() {
  local path="$1"
  local backup="$path.pre-vscode-migration-$MIGRATION_TIMESTAMP"
  local suffix=1

  while [[ -e "$backup" || -L "$backup" ]]; do
    backup="$path.pre-vscode-migration-$MIGRATION_TIMESTAMP-$suffix"
    ((suffix += 1))
  done

  mv "$path" "$backup"
  echo "Preserved $path at $backup"
}

ensure_real_directory() {
  local path="$1"

  if [[ -L "$path" ]]; then
    echo "Cannot use $path as a base directory because it is a symlink." >&2
    exit 1
  fi
  if [[ -e "$path" && ! -d "$path" ]]; then
    echo "Cannot use $path as a base directory because it is not a directory." >&2
    exit 1
  fi

  mkdir -p "$path"
}

ensure_link() {
  local source="$1"
  local target="$2"

  if [[ -L "$target" ]]; then
    if [[ -e "$target" && "$target" -ef "$source" ]]; then
      return
    fi
    rm "$target"
  elif [[ -e "$target" ]]; then
    backup_path "$target"
  fi

  ln -s "$source" "$target"
}

# Convert the legacy ~/.vscode -> ~/.cursor layout while retaining its data.
if [[ -L "$VSCODE_DOTDIR" ]]; then
  if [[ -d "$HOME/.cursor" && ! -L "$HOME/.cursor" && "$VSCODE_DOTDIR" -ef "$HOME/.cursor" ]]; then
    rm "$VSCODE_DOTDIR"
    mv "$HOME/.cursor" "$VSCODE_DOTDIR"
  else
    echo "Cannot migrate $VSCODE_DOTDIR because it does not point to a real ~/.cursor directory." >&2
    exit 1
  fi
elif [[ ! -e "$VSCODE_DOTDIR" && -d "$HOME/.cursor" && ! -L "$HOME/.cursor" ]]; then
  mv "$HOME/.cursor" "$VSCODE_DOTDIR"
fi

ensure_real_directory "$VSCODE_DOTDIR"
ensure_real_directory "$VSCODE_SHARED_DOTDIR"

for dotdir in "${DOTDIR_LINKS[@]}"; do
  ensure_link "$VSCODE_DOTDIR" "$HOME/$dotdir"
done
ensure_link "$VSCODE_SHARED_DOTDIR" "$HOME/.devin-shared"

echo "VS Code filesystem migration complete."

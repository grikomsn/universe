#!/usr/bin/env bash

set -euo pipefail

managed_paths=(
  .bash_profile
  .bashrc
  .profile
  .zprofile
  .zshenv
  .zshrc
  .config/fish
)
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backup_suffix="$(date +%Y%m%d_%H%M%S)"

for path in "${managed_paths[@]}"; do
  source="$repo_dir/$path"
  if [[ ! -e "$source" ]]; then
    echo "Managed source does not exist: $source" >&2
    exit 1
  fi
done

for path in "${managed_paths[@]}"; do
  source="$repo_dir/$path"
  target="$HOME/$path"

  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    continue
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    mv "$target" "$target.backup.$backup_suffix"
  fi
  ln -s "$source" "$target"
done

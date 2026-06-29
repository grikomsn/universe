#!/usr/bin/env bash

set -euo pipefail

# backup existing shell startup files
for file in .bash_profile .bashrc .profile .zprofile .zshenv .zshrc; do
  if [ -f "$HOME/$file" ]; then
    cp "$HOME/$file" "$HOME/$file.backup.$(date +%Y%m%d_%H%M%S)"
  fi
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for file in .bash_profile .bashrc .profile .zprofile .zshenv .zshrc; do
  ln -sf "$repo_dir/$file" "$HOME/$file"
done

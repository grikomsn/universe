#!/usr/bin/env bash

# backup existing .profile .zprofile .zshenv
for file in .profile .zprofile .zshenv; do
  if [ -f "$HOME/$file" ]; then
    cp "$HOME/$file" "$HOME/$file.backup.$(date +%Y%m%d_%H%M%S)"
  fi
done
ln -sf ~/.profile ~/.zprofile
ln -sf ~/.profile ~/.zshenv

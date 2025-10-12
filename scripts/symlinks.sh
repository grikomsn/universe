#!/usr/bin/env bash

# backup existing .profile .zprofile .zshenv
for file in .profile .zprofile .zshenv; do
  if [ -f "$HOME/$file" ]; then
    cp "$HOME/$file" "$HOME/$file.backup.$(date +%Y%m%d_%H%M%S)"
  fi
done
ln -sf ~/.profile ~/.zprofile
ln -sf ~/.profile ~/.zshenv

# symlink cursor to others
ln -sf ~/.cursor ~/.vscode
ln -sf ~/.cursor ~/.vscode-oss
if [[ "$(uname -o)" == "Darwin" ]]; then
  CODE_DATA_DIR=~/Library/Application\ Support/Code
  CURSOR_DATA_DIR=~/Library/Application\ Support/Cursor
  mkdir -p $CODE_DATA_DIR
  ln -sf $CURSOR_DATA_DIR/User/settings.json $CODE_DATA_DIR/User/settings.json
  ln -sf $CURSOR_DATA_DIR/User/keybindings.json $CODE_DATA_DIR/User/keybindings.json
fi

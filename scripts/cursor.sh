#!/usr/bin/env bash

# get extensions from brewfile
readarray -t EXTENSIONS < <(curl -fsSL https://universe.nibras.co/Brewfile | grep '^vscode' | awk '{print $2}' | sed 's/^"\(.*\)"$/\1/')

# symlink cursor to others
mkdir -p ~/.cursor
ln -sf ~/.cursor ~/.vscode
ln -sf ~/.cursor ~/.vscode-oss

# symlink cursor configs
if [[ "$(uname -o)" == "Darwin" ]]; then
  CODE_DATA_DIR=~/Library/Application\ Support/Code
  CURSOR_DATA_DIR=~/Library/Application\ Support/Cursor
else
  CODE_DATA_DIR=~/.config/Code
  CURSOR_DATA_DIR=~/.config/Cursor
fi
mkdir -p $CODE_DATA_DIR
ln -sf $CURSOR_DATA_DIR/User/settings.json $CODE_DATA_DIR/User/settings.json
ln -sf $CURSOR_DATA_DIR/User/keybindings.json $CODE_DATA_DIR/User/keybindings.json

# install extensions via code
if command -v code &>/dev/null; then
  for extension in "${EXTENSIONS[@]}"; do
    code --install-extension "$extension"
  done
else
  echo "VS Code is not installed"
  exit 1
fi

# install extensions again but via cursor
if command -v cursor &>/dev/null; then
  for extension in "${EXTENSIONS[@]}"; do
    cursor --install-extension "$extension"
  done
fi

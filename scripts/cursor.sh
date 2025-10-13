#!/usr/bin/env bash

readarray -t EXTENSIONS < <(curl -fsSL https://universe.nibras.co/Brewfile | grep '^vscode' | awk '{print $2}' | sed 's/^"\(.*\)"$/\1/')

if command -v code &>/dev/null; then
  for extension in "${EXTENSIONS[@]}"; do
    code --install-extension "$extension"
  done
else
  echo "VS Code is not installed"
  exit 1
fi

if command -v cursor &>/dev/null; then
  for extension in "${EXTENSIONS[@]}"; do
    cursor --install-extension "$extension"
  done
fi

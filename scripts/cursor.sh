#!/usr/bin/env bash

# get extensions from brewfile
readarray -t EXTENSIONS < <(curl -fsSL https://universe.nibras.co/Brewfile | grep '^vscode' | awk '{print $2}' | sed 's/^"\(.*\)"$/\1/')

# symlink cursor to others
mkdir -p "$HOME/.cursor"
ln -sf "$HOME/.cursor" "$HOME/.vscode"
ln -sf "$HOME/.cursor" "$HOME/.vscode-oss"

# symlink cursor configs
if [[ "$(uname -o)" == "Darwin" ]]; then
	CODE_DATA_DIR="$HOME/Library/Application Support/Code"
	CURSOR_DATA_DIR="$HOME/Library/Application Support/Cursor"
else
	CODE_DATA_DIR="$HOME/.config/Code"
	CURSOR_DATA_DIR="$HOME/.config/Cursor"
fi

# ensure directories exist
mkdir -p "$CODE_DATA_DIR/User"
mkdir -p "$CURSOR_DATA_DIR/User"

# early stub if first time setup
if [ ! -f "$CURSOR_DATA_DIR/User/settings.json" ]; then
	echo '{}' >"$CURSOR_DATA_DIR/User/settings.json"
fi
if [ ! -f "$CURSOR_DATA_DIR/User/keybindings.json" ]; then
	echo '[]' >"$CURSOR_DATA_DIR/User/keybindings.json"
fi

# create json symlinks
ln -sf "$CURSOR_DATA_DIR/User/settings.json" "$CODE_DATA_DIR/User/settings.json"
ln -sf "$CURSOR_DATA_DIR/User/keybindings.json" "$CODE_DATA_DIR/User/keybindings.json"

if command -v cursor &>/dev/null; then
	for extension in "${EXTENSIONS[@]}"; do
		cursor --install-extension "$extension"
	done
fi

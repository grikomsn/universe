#!/usr/bin/env bash

# get extensions from brewfile
readarray -t EXTENSIONS < <(curl -fsSL https://universe.nibras.co/Brewfile | grep '^vscode' | awk '{print $2}' | sed 's/^"\(.*\)"$/\1/')

# dotdir values for other vscode forks
DOTDIR_VALUES=(
	".antigravity"
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

	# iterate on user symlink targets
	for USER_SYMLINK_TARGET in "${USER_SYMLINK_TARGETS[@]}"; do
		ln -sf "$CURSOR_DATA_DIR/User/$USER_SYMLINK_TARGET" "$TARGET_DATA_DIR/User/$USER_SYMLINK_TARGET"
	done
done

# install only non-existing extensions via `cursor`
if command -v cursor &>/dev/null; then
	readarray -t INSTALLED_EXTENSIONS < <(cursor --list-extensions)
	for extension in "${EXTENSIONS[@]}"; do
		if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -qx "$extension"; then
			cursor --install-extension "$extension"
		fi
	done
fi

# install only non-existing extensions via `code`
if command -v code &>/dev/null; then
	readarray -t INSTALLED_EXTENSIONS < <(code --list-extensions)
	for extension in "${EXTENSIONS[@]}"; do
		if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -qx "$extension"; then
			code --install-extension "$extension"
		fi
	done
fi

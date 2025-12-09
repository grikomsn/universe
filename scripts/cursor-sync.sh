#!/usr/bin/env bash

# get extensions from brewfile
readarray -t EXTENSIONS < <(curl -fsSL https://universe.nibras.co/Brewfile | grep '^vscode' | awk '{print $2}' | sed 's/^"\(.*\)"$/\1/')

if command -v cursor &>/dev/null; then
	readarray -t INSTALLED_EXTENSIONS < <(cursor --list-extensions)
elif command -v code &>/dev/null; then
	readarray -t INSTALLED_EXTENSIONS < <(code --list-extensions)
else
	INSTALLED_EXTENSIONS=()
fi

if command -v cursor &>/dev/null; then
	# Install missing extensions
	for extension in "${EXTENSIONS[@]}"; do
		if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -qx "$extension"; then
			cursor --install-extension "$extension"
		fi
	done
	# Uninstall extra extensions
	for ext in "${INSTALLED_EXTENSIONS[@]}"; do
		if ! printf '%s\n' "${EXTENSIONS[@]}" | grep -qx "$ext"; then
			cursor --uninstall-extension "$ext"
		fi
	done
fi

if command -v code &>/dev/null; then
	# Install missing extensions
	for extension in "${EXTENSIONS[@]}"; do
		if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -qx "$extension"; then
			code --install-extension "$extension"
		fi
	done
	# Uninstall extra extensions
	for ext in "${INSTALLED_EXTENSIONS[@]}"; do
		if ! printf '%s\n' "${EXTENSIONS[@]}" | grep -qx "$ext"; then
			code --uninstall-extension "$ext"
		fi
	done
fi

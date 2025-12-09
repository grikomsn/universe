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

# Find extensions in source but not installed
echo "=== Extensions in source but NOT installed ==="
NOT_INSTALLED=()
for extension in "${EXTENSIONS[@]}"; do
	if ! printf '%s\n' "${INSTALLED_EXTENSIONS[@]}" | grep -qx "$extension"; then
		NOT_INSTALLED+=("$extension")
	fi
done

if [[ ${#NOT_INSTALLED[@]} -eq 0 ]]; then
	echo "(none)"
else
	printf '%s\n' "${NOT_INSTALLED[@]}"
fi

echo ""

# Find extensions installed but not in source
echo "=== Extensions installed but NOT in source ==="
EXTRA_INSTALLED=()
for ext in "${INSTALLED_EXTENSIONS[@]}"; do
	if ! printf '%s\n' "${EXTENSIONS[@]}" | grep -qx "$ext"; then
		EXTRA_INSTALLED+=("$ext")
	fi
done

if [[ ${#EXTRA_INSTALLED[@]} -eq 0 ]]; then
	echo "(none)"
else
	printf '%s\n' "${EXTRA_INSTALLED[@]}"
fi

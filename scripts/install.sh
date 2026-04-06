#!/usr/bin/env bash

sudo -v
while true; do
	sudo -n true
	sleep 60
	kill -0 "$$" || exit
done 2>/dev/null &

mkdir -p ~/Projects ~/Scripts ~/Temporary ~/Workspace ~/.cursor
ln -sf ~/.cursor ~/.vscode
ln -sf ~/.cursor ~/.vscode-oss

if [[ "$(uname -o)" == "Darwin" ]]; then
	xcode-select --install
	read -p "Press [Enter] key after Xcode Command Line Tools are installed..."

	if [[ "$(uname -m)" == "arm64" ]]; then
		softwareupdate --install-rosetta --agree-to-license
		read -p "Press [Enter] key after Rosetta is installed..."
	fi

	sudo xcodebuild -license accept
	sudo xcodebuild -runFirstLaunch

	curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
	if [[ "$(uname -m)" == "arm64" ]]; then
		eval $(/opt/homebrew/bin/brew shellenv)
	else
		eval $(/usr/local/bin/brew shellenv)
	fi

	curl -fsSL https://universe.nibras.co/Brewfile >~/.Brewfile
	brew bundle --global
fi

if command -v mkcert >/dev/null 2>&1; then
	mkcert -install
fi

curl -sSL https://raw.githubusercontent.com/yarlson/lnk/main/install.sh | bash
lnk init -r https://github.com/grikomsn/universe.git
lnk pull

if [[ "$(uname -o)" == "Darwin" ]]; then
	lnk pull -H darwin
fi
if [[ "$(uname -s)" == "Linux" ]]; then
	lnk pull -H linux
fi

# Ensure npmrc has audit=false and fund=false without clobbering existing content
npmrc_file="$HOME/.npmrc"
ensure_npmrc_setting() {
	local key="$1"
	local value="$2"
	local line="${key}=${value}"
	
	if [[ -f "$npmrc_file" ]]; then
		if grep -q "^${key}=" "$npmrc_file" 2>/dev/null; then
			# Key exists, update if value differs
			sed -i.bak "s/^${key}=.*/${line}/" "$npmrc_file" && rm -f "${npmrc_file}.bak"
		else
			# Key doesn't exist, append it
			echo "$line" >> "$npmrc_file"
		fi
	else
		# File doesn't exist, create it
		echo "$line" > "$npmrc_file"
	fi
}

ensure_npmrc_setting "audit" "false"
ensure_npmrc_setting "fund" "false"

curl -fsSL https://bun.com/install | bash
curl -fsSL https://deno.land/install.sh | bash
curl -fsSL https://fnm.vercel.app/install | bash
curl -fsSL https://sh.rustup.rs | bash

curl -fsSL https://ampcode.com/install.sh | bash
curl -fsSL https://opencode.ai/install | bash
curl -fsSL https://astral.sh/uv/install.sh | bash

#!/usr/bin/env bash

mkdir -p ~/Projects ~/Scripts ~/Temporary ~/Workspace

if [[ "$(uname -o)" == "Darwin" ]]; then
    xcode-select --install
    softwareupdate --install-rosetta --agree-to-license
    read -p "Press [Enter] key after Xcode Command Line Tools are installed..."

    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
    if [[ -z "${HOMEBREW_PREFIX}" ]]; then
        if [[ "$(uname -m)" == "arm64" ]]; then
            export HOMEBREW_PREFIX="/opt/homebrew"
        else
            export HOMEBREW_PREFIX="/usr/local"
        fi
    fi

    if [[ -d "${HOMEBREW_PREFIX}" ]]; then
        source "$HOMEBREW_PREFIX/bin/brew" shellenv
        export PATH="$HOMEBREW_PREFIX/opt/curl/bin:$PATH"
        export PATH="$HOMEBREW_PREFIX/opt/dotnet/libexec:$PATH"
    fi

    curl -fsSL https://universe.nibras.co/.Brewfile > ~/.Brewfile
    brew bundle --global
fi

curl -sSL https://raw.githubusercontent.com/yarlson/lnk/main/install.sh | bash
lnk init -r https://github.com/grikomsn/universe.git

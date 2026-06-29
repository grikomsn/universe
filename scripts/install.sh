#!/usr/bin/env bash
#
# install.sh - Bootstrap script for fresh macOS/Linux installations
# Installs development tools, package managers, and dotfiles via lnk

set -euo pipefail

REPO_URL="https://github.com/grikomsn/universe.git"
REPO_DIR="$HOME/.config/lnk"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

run_remote_installer() {
  local name="$1"
  local url="$2"
  local expected_sha256="${3:-}"
  local installer="$TEMP_DIR/$name.sh"
  local actual_sha256

  curl -fsSL "$url" -o "$installer"
  if [[ -n "$expected_sha256" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual_sha256="$(sha256sum "$installer" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
      actual_sha256="$(shasum -a 256 "$installer" | awk '{print $1}')"
    else
      echo "No SHA-256 checksum utility found." >&2
      exit 1
    fi
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
      echo "Checksum mismatch for $name installer." >&2
      exit 1
    fi
  fi
  bash "$installer"
}

sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

mkdir -p ~/Projects ~/Scripts ~/Temporary ~/Workspace ~/.cursor
ln -sf ~/.cursor ~/.vscode
ln -sf ~/.cursor ~/.vscode-oss

if [[ "$(uname -s)" == "Darwin" ]]; then
  xcode-select --install
  read -p "Press [Enter] key after Xcode Command Line Tools are installed..."

  if [[ "$(uname -m)" == "arm64" ]]; then
    softwareupdate --install-rosetta --agree-to-license
    read -p "Press [Enter] key after Rosetta is installed..."
  fi

  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch

  run_remote_installer \
    homebrew \
    "${HOMEBREW_INSTALL_URL:-https://raw.githubusercontent.com/Homebrew/install/db5debe9b6dac00d87e6a2277a5e2b6c2b0fb773/install.sh}" \
    "${HOMEBREW_INSTALL_SHA256:-}"
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  curl -fsSL https://universe.nibras.co/Brewfile >~/.Brewfile
  brew bundle --global
fi

if command -v mkcert >/dev/null 2>&1; then
  mkcert -install
fi

run_remote_installer \
  lnk \
  "${LNK_INSTALL_URL:-https://raw.githubusercontent.com/yarlson/lnk/c5db74b2f514d886e8bf5e3bf4de4ba4979ad313/install.sh}" \
  "${LNK_INSTALL_SHA256:-}"
lnk init -r "$REPO_URL"
lnk pull

if [[ "$(uname -s)" == "Darwin" ]]; then
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
      echo "$line" >>"$npmrc_file"
    fi
  else
    # File doesn't exist, create it
    echo "$line" >"$npmrc_file"
  fi
}

ensure_npmrc_setting "audit" "false"
ensure_npmrc_setting "fund" "false"

# Mutable installer endpoints are pinned by content hash. Update the URL and
# corresponding default hash together when upgrading an installer.
run_remote_installer bun "${BUN_INSTALL_URL:-https://bun.com/install}" \
  "${BUN_INSTALL_SHA256:-bab8acfb046aac8c72407bdcce903957665d655d7acaa3e11c7c4616beae68dd}"
run_remote_installer deno "${DENO_INSTALL_URL:-https://deno.land/install.sh}" \
  "${DENO_INSTALL_SHA256:-83f19ea13f6d7884f4dc0e2f92e7e08e7589204138d9b6edfcd53c3f07b3273b}"
run_remote_installer fnm "${FNM_INSTALL_URL:-https://fnm.vercel.app/install}" \
  "${FNM_INSTALL_SHA256:-8431644b1c205ad25d4b09cfe10e0688944d1d2cd542f38d7b3b10e954db8ad9}"
run_remote_installer rustup "${RUSTUP_INSTALL_URL:-https://sh.rustup.rs}" \
  "${RUSTUP_INSTALL_SHA256:-6c30b75a75b28a96fd913a037c8581b580080b6ee9b8169a3c0feb1af7fe8caf}"

run_remote_installer amp "${AMP_INSTALL_URL:-https://ampcode.com/install.sh}" \
  "${AMP_INSTALL_SHA256:-8fcc17808b55b1a6ec6b54aa28877dbff9a5cab4fef8e992c1cf82d8ceaf1e46}"
run_remote_installer opencode "${OPENCODE_INSTALL_URL:-https://opencode.ai/install}" \
  "${OPENCODE_INSTALL_SHA256:-fc3c1b2123f49b6df545a7622e5127d21cd794b15134fc3b66e1ca49f7fb297e}"
run_remote_installer uv "${UV_INSTALL_URL:-https://astral.sh/uv/install.sh}" \
  "${UV_INSTALL_SHA256:-ca2de1bca2913ba30ce88658b6d90a663c627ecac378803aa58084a9adb35a46}"

"$REPO_DIR/scripts/cleanup-shell-injections.sh"

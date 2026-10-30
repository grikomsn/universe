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

  shift 3
  local extra_args=()
  if [[ $# -gt 0 ]]; then
    extra_args=("$@")
  fi

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
  bash "$installer" "${extra_args[@]+"${extra_args[@]}"}"
}

# Headless-safe sudo refresh: sudo -v demands a TTY on hosts where sudo
# itself works via NOPASSWD, which would abort the whole bootstrap.
sudo -n true 2>/dev/null || sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

mkdir -p ~/Projects ~/Scripts ~/Temporary ~/Workspace ~/.vscode ~/.vscode-shared

if [[ "$(uname -s)" == "Darwin" ]]; then
  # `xcode-select --install` exits 1 when the tools already exist, which would
  # abort a re-run under `set -e`. The prompt reads /dev/tty: under
  # `curl | bash` stdin is this script, so a plain `read` would swallow its
  # next line instead of waiting.
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install
    read -r -p "Press [Enter] key after Xcode Command Line Tools are installed..." </dev/tty
  fi

  # softwareupdate blocks until Rosetta is installed; no prompt needed.
  if [[ "$(uname -m)" == "arm64" && ! -f /Library/Apple/usr/share/rosetta/rosetta ]]; then
    softwareupdate --install-rosetta --agree-to-license
  fi

  run_remote_installer \
    homebrew \
    "${HOMEBREW_INSTALL_URL:-https://raw.githubusercontent.com/Homebrew/install/db5debe9b6dac00d87e6a2277a5e2b6c2b0fb773/install.sh}" \
    "${HOMEBREW_INSTALL_SHA256:-}"
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if [[ "$(uname -s)" == "Linux" ]]; then
  # Headless-safe defaults: skip the ~10 GB CUDA marker-pdf wheels, and
  # keep rustup's TTY-gated prompt out of non-interactive installs.
  export SKIP_MARKER_PDF="${SKIP_MARKER_PDF:-1}"
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y fish git jq curl wget
  fi
  if command -v fish >/dev/null 2>&1; then
    fish_path="$(command -v fish)"
    grep -qx "$fish_path" /etc/shells 2>/dev/null || echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    sudo chsh -s "$fish_path" "$(id -un)" || true
  fi
fi

run_remote_installer \
  lnk \
  "${LNK_INSTALL_URL:-https://raw.githubusercontent.com/yarlson/lnk/c5db74b2f514d886e8bf5e3bf4de4ba4979ad313/install.sh}" \
  "${LNK_INSTALL_SHA256:-}"
# bootstrap.sh runs once at the end, after the toolchain installers below.
lnk init -r "$REPO_URL" --no-bootstrap 2>/dev/null || lnk pull
lnk pull

if [[ "$(uname -s)" == "Darwin" ]]; then
  lnk pull -H darwin
fi
if [[ "$(uname -s)" == "Linux" ]]; then
  lnk pull -H linux
fi

bash "$REPO_DIR/scripts/vscode-migrate.sh"

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
#
# lnk has already linked the shell config into this repo, so any installer
# that edits rc files would dirty tracked files (config.fish, conf.d/*.fish,
# .profile, .bashrc, .zshenv). The fish and POSIX configs already set up every
# tool's PATH, so each installer is told to leave them alone.

# bun appends to config.fish, .zshrc or .bashrc depending on $SHELL.
SHELL=unknown run_remote_installer bun "${BUN_INSTALL_URL:-https://bun.com/install}" \
  "${BUN_INSTALL_SHA256:-04882bf41679d49d9af108657a1e5515bf04fdf2940d12c0d0b1e5d79dc53be8}"
# deno runs an interactive rc-editing setup whenever stdout is a terminal,
# unless CI is set.
CI=true run_remote_installer deno "${DENO_INSTALL_URL:-https://deno.land/install.sh}" \
  "${DENO_INSTALL_SHA256:-83f19ea13f6d7884f4dc0e2f92e7e08e7589204138d9b6edfcd53c3f07b3273b}"
run_remote_installer fnm "${FNM_INSTALL_URL:-https://fnm.vercel.app/install}" \
  "${FNM_INSTALL_SHA256:-8431644b1c205ad25d4b09cfe10e0688944d1d2cd542f38d7b3b10e954db8ad9}" \
  --skip-shell
run_remote_installer rustup "${RUSTUP_INSTALL_URL:-https://sh.rustup.rs}" \
  "${RUSTUP_INSTALL_SHA256:-9502b514362a21096210d498f143b8cdacda365d3dfcf45e8f5541e089ccafc0}" \
  -y --no-modify-path

# OpenCode v2 CLI. The installer self-modifies shell rc files unless told not
# to; cleanup-shell-injections.sh remains a backstop for older installs.
run_remote_installer opencode "${OPENCODE_INSTALL_URL:-https://opencode.ai/v2/install}" \
  "${OPENCODE_INSTALL_SHA256:-1cde9fc3503fd89a2cec67f5f84d7a59e51fc5cdadce06819aa64af573a80136}" \
  --no-modify-path
UV_NO_MODIFY_PATH=1 run_remote_installer uv "${UV_INSTALL_URL:-https://astral.sh/uv/install.sh}" \
  "${UV_INSTALL_SHA256:-f7a56e7afaec49a3bcbc3ac3cdbe917e7c6ce30e0d815308a12e531aa5ef23b7}"

# Parallel CLI. The installer appends a PATH line to the detected shell's rc
# file when ~/.local/bin is missing from PATH; 00-core.fish already exports it,
# so neutralize shell detection to keep the lnk-managed config.fish untouched.
SHELL=unknown run_remote_installer parallel-cli \
  "${PARALLEL_INSTALL_URL:-https://raw.githubusercontent.com/parallel-web/parallel-web-tools/v0.9.4/install-cli.sh}" \
  "${PARALLEL_INSTALL_SHA256:-9e7e9cb10c4948e13023bfd1078b577362e4e7054c35a0d83927310f21846371}"

# Render CLI installs to ~/.local/bin for non-root users, /usr/local/bin only
# under sudo; no rc-file writes.
run_remote_installer render \
  "${RENDER_INSTALL_URL:-https://raw.githubusercontent.com/render-oss/cli/73c017c953de5918bc2a5d9f1754f0ef965a6df2/bin/install.sh}" \
  "${RENDER_INSTALL_SHA256:-c9722bf40bb869d35cc94f74d93c8027ed7980b5adae5f9a368b68cc1603d540}"

# git-hunk honors GIT_HUNK_INSTALL_DIR and defaults to ~/.local/bin; no rc-file
# writes, no prompts.
run_remote_installer git-hunk \
  "${GITHUNK_INSTALL_URL:-https://raw.githubusercontent.com/nexxeln/git-hunk/2d00a577cc1a7946737e36b318923639facd25b3/install.sh}" \
  "${GITHUNK_INSTALL_SHA256:-e960acc8c8de0156a1e0dadd75ac28af1f57850058c4433b4830596f3c8966d1}"

"$REPO_DIR/scripts/cleanup-shell-injections.sh"

# Skills, packages (brew bundle / dnf from the repo manifests), language
# globals, and editor extensions.
bash "$REPO_DIR/bootstrap.sh"

# xcodebuild needs the full Xcode app, which only arrives with the Brewfile's
# mas entries above; with just the Command Line Tools it exits 1.
if [[ "$(uname -s)" == "Darwin" ]] && xcodebuild -version >/dev/null 2>&1; then
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
fi

if command -v mkcert >/dev/null 2>&1; then
  mkcert -install
fi

#!/usr/bin/env bash

set -euo pipefail

# packages.sh - install platform packages from the parity manifests.
#   Darwin: brew bundle --global (Brewfile)
#   Linux:  sudo dnf install from Linuxfile (Fedora and friends)

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
os_name="$(uname -s)"

case "$os_name" in
Darwin)
  command -v brew >/dev/null || {
    echo "brew not found" >&2
    exit 1
  }
  brew bundle --global --file="$repo/Brewfile"
  ;;
Linux)
  linuxfile="$repo/Linuxfile"
  [[ -f "$linuxfile" ]] || {
    echo "no Linuxfile at $linuxfile" >&2
    exit 1
  }
  if command -v dnf >/dev/null; then
    mapfile -t packages < <(grep -vE '^\s*(#|$)' "$linuxfile")
    ((${#packages[@]} > 0)) || {
      echo "no packages listed in $linuxfile" >&2
      exit 1
    }
    # dnf5 aborts the whole transaction on a single unknown name;
    # --skip-unavailable installs the resolvable ones and reports the rest.
    if ! sudo dnf install -y --skip-unavailable "${packages[@]}"; then
      echo "dnf install failed" >&2
      exit 1
    fi
    for package in "${packages[@]}"; do
      if ! dnf -q repoquery "$package" 2>/dev/null | grep -q .; then
        echo "skipped (not in repos): $package" >&2
      fi
    done
  else
    echo "dnf not found; only Fedora-family Linux is supported." >&2
    exit 1
  fi
  ;;
*)
  echo "unsupported platform: $os_name" >&2
  exit 1
  ;;
esac

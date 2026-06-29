#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname -s)" = "Linux" ] && command -v NetworkManager >/dev/null 2>&1 && command -v systemd-resolved >/dev/null 2>&1; then
  operator_user="${SUDO_USER:-${USER:-$(id -un)}}"
  sudo tailscale set --operator="$operator_user"

  # https://tailscale.com/kb/1188/linux-dns
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  sudo systemctl restart systemd-resolved
  sudo systemctl restart NetworkManager
  sudo systemctl restart tailscaled
fi

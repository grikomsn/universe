#!/usr/bin/env bash

if [ "$(uname -s)" = "Linux" ] && command -v NetworkManager >/dev/null 2>&1 && command -v systemd-resolved >/dev/null 2>&1; then
    sudo tailscale set --operator=$USER

    # https://tailscale.com/kb/1188/linux-dns
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    sudo systemctl restart systemd-resolved
    sudo systemctl restart NetworkManager
    sudo systemctl restart tailscaled
fi

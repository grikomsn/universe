#!/usr/bin/env bash
set -euo pipefail

action="${1:-status}"

usage() {
  cat <<'EOF'
Usage:
  herdr-server.sh status
  herdr-server.sh enable
  herdr-server.sh disable

Manage a persistent headless herdr server via a systemd user unit:
  enable   install the unit, enable linger, and start the server
  disable  stop the server, disable the unit, and turn linger off
  status   show unit, linger, and herdr server state

Run as the sudo-capable target user; the script invokes sudo itself.
Requires herdr in ~/.local/bin (the official installer layout).
Linux only (macOS would need a launchd unit).
EOF
}

case "$action" in
status | enable | disable) ;;
-h | --help | help)
  usage
  exit 0
  ;;
*)
  usage >&2
  exit 2
  ;;
esac

[[ "$(uname -s)" == "Linux" ]] || {
  echo "Linux only (macOS would need a launchd unit)." >&2
  exit 1
}

herdr_bin="$HOME/.local/bin/herdr"
unit_dir="$HOME/.config/systemd/user"
unit_file="$unit_dir/herdr-server.service"

[[ -x "$herdr_bin" ]] || {
  echo "herdr not found at $herdr_bin; run the official installer first." >&2
  exit 1
}

require_sudo() {
  sudo -n true 2>/dev/null || sudo -v
}

install_unit() {
  mkdir -p "$unit_dir"
  cat >"$unit_file" <<UNIT
[Unit]
Description=Herdr headless server
After=network-online.target

[Service]
ExecStart=%h/.local/bin/herdr server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT
  systemctl --user daemon-reload
}

case "$action" in
status)
  echo "== unit"
  systemctl --user is-enabled herdr-server.service 2>/dev/null || true
  systemctl --user is-active herdr-server.service 2>/dev/null || true
  echo "== linger"
  loginctl show-user "$(id -un)" 2>/dev/null | grep -i linger || true
  echo "== herdr"
  "$herdr_bin" status 2>/dev/null | sed -n '/^server:/,/^$/p' || true
  ;;
enable)
  require_sudo
  sudo loginctl enable-linger "$(id -un)"
  install_unit
  systemctl --user enable --now herdr-server.service
  sleep 2
  "$herdr_bin" status 2>/dev/null | sed -n '/^server:/,/^$/p'
  echo "herdr server enabled and running"
  ;;
disable)
  require_sudo
  systemctl --user disable --now herdr-server.service 2>/dev/null || true
  sudo loginctl disable-linger "$(id -un)"
  echo "herdr server disabled; linger off"
  ;;
esac

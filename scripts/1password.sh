#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" == "Darwin" ]]; then
  label="com.1password.SSH_AUTH_SOCK"
  launch_agents_dir="$HOME/Library/LaunchAgents"
  plist="$launch_agents_dir/$label.plist"
  source_socket="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  target_socket="$(launchctl getenv SSH_AUTH_SOCK)"
  domain="gui/$(id -u)"

  if [[ -z "$target_socket" ]]; then
    echo "SSH_AUTH_SOCK is not registered in the launchd environment." >&2
    exit 1
  fi

  mkdir -p "$launch_agents_dir"
  cat <<EOF >"$plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/ln</string>
    <string>-sf</string>
    <string>$source_socket</string>
    <string>$target_socket</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

  launchctl bootout "$domain/$label" 2>/dev/null || true
  launchctl bootstrap "$domain" "$plist"
  launchctl kickstart "$domain/$label"
else
  autostart_dir="$HOME/.config/autostart"
  autostart_file="$autostart_dir/gnome-keyring-ssh.desktop"
  autostart_source="/etc/xdg/autostart/gnome-keyring-ssh.desktop"

  if [[ -f "$autostart_source" ]]; then
    mkdir -p "$autostart_dir"
    cp "$autostart_source" "$autostart_file"
    if ! grep -Fqx -- 'Hidden=true' "$autostart_file"; then
      echo "Hidden=true" >>"$autostart_file"
    fi
  fi
fi

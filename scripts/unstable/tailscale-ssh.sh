#!/usr/bin/env bash

set -euo pipefail

action="${1:-status}"
os_name="$(uname -s)"

usage() {
  cat <<'EOF'
Usage: tailscale-ssh.sh {status|enable|disable}

Manages only the local Tailscale SSH preference. It does not edit tailnet
grants, SSH policy, OpenSSH, firewalls, DNS, or SELinux configuration.
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

command -v tailscale >/dev/null 2>&1 || {
  echo "tailscale CLI is not installed." >&2
  exit 1
}

preference() {
  tailscale debug prefs 2>/dev/null |
    awk -F': ' '/"RunSSH"/ {gsub(/[ ,]/, "", $2); print $2; exit}'
}

macos_server_supported() {
  [[ "$os_name" != "Darwin" ]] && return 0
  command -v tailscaled >/dev/null 2>&1 && pgrep -x tailscaled >/dev/null 2>&1
}

platform_supported() {
  case "$os_name" in
  Linux) return 0 ;;
  Darwin) macos_server_supported ;;
  *) return 1 ;;
  esac
}

status() {
  printf 'OS:                    %s\n' "$os_name"
  printf 'Tailscale version:     %s\n' "$(tailscale version 2>/dev/null | head -n 1)"
  printf 'Tailscale SSH enabled: %s\n' "$(preference || printf 'unknown')"
  if platform_supported; then
    printf 'Server capability:     supported\n'
  elif [[ "$os_name" == "Darwin" ]]; then
    printf 'Server capability:     unsupported by GUI/App Store Tailscale build\n'
    printf '                           (open-source tailscale + tailscaled required)\n'
  else
    printf 'Server capability:     unsupported platform\n'
  fi
  printf 'Node:\n'
  tailscale status --self 2>/dev/null | sed -n '1p' || true
  health="$(tailscale status 2>/dev/null | sed -n '/^# Health check:/,$p' || true)"
  if [[ -n "$health" ]]; then
    printf '%s\n' "$health"
  fi
  printf 'Native OpenSSH:        '
  if [[ "$os_name" == "Linux" ]] && command -v systemctl >/dev/null 2>&1; then
    native_state="$(systemctl is-active sshd.service 2>/dev/null || true)"
    printf '%s\n' "${native_state:-inactive}"
  elif [[ "$os_name" == "Darwin" ]]; then
    launchctl print system/com.openssh.sshd >/dev/null 2>&1 && printf 'loaded\n' || printf 'not loaded\n'
  else
    printf 'unknown\n'
  fi
}

confirm() {
  local expected="$1"
  local response
  printf 'Type %s to continue: ' "$expected"
  read -r response
  [[ "$response" == "$expected" ]]
}

set_preference() {
  local value="$1"
  if ! platform_supported; then
    if [[ "$os_name" == "Darwin" ]]; then
      echo "This Mac uses a Tailscale GUI/system-extension build, which cannot host Tailscale SSH." >&2
      echo "Use native OpenSSH over the tailnet, or install the open-source tailscaled distribution." >&2
    else
      echo "Tailscale SSH server is unsupported on $os_name." >&2
    fi
    exit 1
  fi

  echo "This changes only the local RunSSH preference."
  echo "Tailnet network grants and SSH policy must independently permit access."
  if [[ "$value" == "true" ]]; then
    confirm ENABLE || exit 1
    sudo tailscale set --ssh
  else
    confirm DISABLE || exit 1
    sudo tailscale set --ssh=false
  fi

  actual="$(preference)"
  if [[ "$actual" != "$value" ]]; then
    echo "Preference verification failed: expected $value, got ${actual:-unknown}." >&2
    exit 1
  fi
  status
}

case "$action" in
status) status ;;
enable) set_preference true ;;
disable) set_preference false ;;
esac

#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/../.." && pwd)"
os_name="$(uname -s)"
strict=0
warnings=0

if [[ "${1:-}" == "--strict" ]]; then
  strict=1
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--strict]" >&2
  exit 2
fi

section() {
  printf '\n== %s ==\n' "$1"
}

item() {
  printf '%-28s %s\n' "$1" "$2"
}

warn() {
  item "$1" "WARN: $2"
  warnings=$((warnings + 1))
}

command_path() {
  command -v "$1" 2>/dev/null || printf 'missing'
}

service_state() {
  local unit="$1"
  local state
  if command -v systemctl >/dev/null 2>&1; then
    state="$(systemctl is-active "$unit" 2>/dev/null || true)"
    printf '%s' "${state:-inactive}"
  else
    printf 'unsupported'
  fi
}

section "Platform"
item "OS" "$os_name"
item "Kernel" "$(uname -r)"
item "Architecture" "$(uname -m)"
if [[ "$os_name" == "Linux" && -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  item "Distribution" "${PRETTY_NAME:-unknown}"
elif [[ "$os_name" == "Darwin" ]]; then
  item "macOS" "$(sw_vers -productVersion) ($(sw_vers -buildVersion))"
fi

section "Tooling"
for tool in git ssh ssh-keygen tailscale lnk fish; do
  path="$(command_path "$tool")"
  if [[ "$path" == "missing" ]]; then
    warn "$tool" "not installed"
  else
    item "$tool" "$path"
  fi
done
item "client sshd in PATH" "$(command_path sshd)"
if [[ "$os_name" == "Darwin" ]]; then
  item "platform sshd" "/usr/sbin/sshd"
elif [[ -x /usr/sbin/sshd ]]; then
  item "platform sshd" "/usr/sbin/sshd"
fi

section "lnk repository"
item "Repository" "$repo_dir"
if git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  item "Branch" "$(git -C "$repo_dir" branch --show-current)"
  dirty="$(git -C "$repo_dir" status --short)"
  if [[ -n "$dirty" ]]; then
    warn "Worktree" "contains uncommitted changes"
    printf '%s\n' "$dirty" | sed 's/^/  /'
  else
    item "Worktree" "clean"
  fi
else
  warn "Repository" "not a Git worktree"
fi

manifest_errors=0
for manifest in .lnk .lnk.linux .lnk.darwin; do
  [[ -f "$repo_dir/$manifest" ]] || continue
  while IFS= read -r managed_path; do
    [[ -n "$managed_path" && "$managed_path" != \#* ]] || continue
    if [[ "$manifest" == ".lnk" ]]; then
      source_path="$repo_dir/$managed_path"
    else
      host="${manifest#.lnk.}"
      source_path="$repo_dir/$host.lnk/$managed_path"
    fi
    if [[ ! -e "$source_path" && ! -L "$source_path" ]]; then
      printf '  missing source: %s -> %s\n' "$manifest:$managed_path" "$source_path"
      manifest_errors=$((manifest_errors + 1))
    fi
  done <"$repo_dir/$manifest"
done
if ((manifest_errors)); then
  warn "Manifests" "$manifest_errors missing source(s)"
else
  item "Manifests" "all sources present"
fi

section "Git signing"
if command -v git >/dev/null 2>&1; then
  signing_format="$(git config --get gpg.format 2>/dev/null || true)"
  signing_program="$(git config --get gpg.ssh.program 2>/dev/null || true)"
  signing_key="$(git config --get user.signingkey 2>/dev/null || true)"
  item "Format" "${signing_format:-unset}"
  item "Program" "${signing_program:-default ssh-keygen}"
  item "Key" "${signing_key:-unset}"
  if [[ -n "$signing_program" && ! -x "$signing_program" ]]; then
    warn "Signing program" "not executable"
  fi
  if [[ "$signing_key" == /* || "$signing_key" == ~/* ]]; then
    expanded_key="${signing_key/#\~/$HOME}"
    if [[ -f "$expanded_key" ]]; then
      item "Key fingerprint" "$(ssh-keygen -lf "$expanded_key" 2>/dev/null || printf 'unreadable')"
    else
      warn "Signing key" "file does not exist"
    fi
  fi
fi

section "SSH client and agent"
auth_sock="${SSH_AUTH_SOCK:-}"
if [[ -n "$auth_sock" && -S "$auth_sock" ]]; then
  item "SSH_AUTH_SOCK" "$auth_sock"
else
  warn "SSH_AUTH_SOCK" "unset or not a socket"
fi
if command -v ssh-add >/dev/null 2>&1; then
  agent_summary="$(ssh-add -l 2>&1 || true)"
  item "Agent identities" "${agent_summary:-none}"
fi

section "1Password"
if [[ "$os_name" == "Darwin" ]]; then
  op_helper="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
  op_socket="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
else
  op_helper="/opt/1Password/op-ssh-sign"
  op_socket="$HOME/.1password/agent.sock"
fi
if [[ -x "$op_helper" ]]; then
  item "Signing helper" "$op_helper"
else
  warn "Signing helper" "missing: $op_helper"
fi
if [[ -S "$op_socket" ]]; then
  item "Agent socket" "$op_socket"
else
  warn "Agent socket" "missing: $op_socket"
fi

section "Native SSH server"
if [[ "$os_name" == "Linux" ]]; then
  item "sshd service" "$(service_state sshd.service)"
  if command -v ss >/dev/null 2>&1; then
    listeners="$(ss -ltn 'sport = :22' 2>/dev/null | tail -n +2 | wc -l)"
    item "Port 22 listeners" "$listeners"
  fi
  if command -v getenforce >/dev/null 2>&1; then
    item "SELinux" "$(getenforce)"
  fi
elif [[ "$os_name" == "Darwin" ]]; then
  if launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
    item "Remote Login" "loaded"
  else
    item "Remote Login" "not loaded"
  fi
  if [[ "$(command_path sshd)" == /opt/homebrew/* ]]; then
    warn "PATH sshd" "Homebrew sshd differs from Apple Remote Login server"
  fi
fi

section "Tailscale"
if command -v tailscale >/dev/null 2>&1; then
  tailscale_version="$(tailscale version 2>/dev/null | head -n 1 || true)"
  item "Version" "${tailscale_version:-unknown}"
  prefs="$(tailscale debug prefs 2>/dev/null || true)"
  run_ssh="$(printf '%s\n' "$prefs" | awk -F': ' '/"RunSSH"/ {gsub(/[ ,]/, "", $2); print $2; exit}')"
  want_running="$(printf '%s\n' "$prefs" | awk -F': ' '/"WantRunning"/ {gsub(/[ ,]/, "", $2); print $2; exit}')"
  item "Connected preference" "${want_running:-unknown}"
  item "Tailscale SSH" "${run_ssh:-unknown}"
  if [[ "$os_name" == "Darwin" ]]; then
    if command -v tailscaled >/dev/null 2>&1 && pgrep -x tailscaled >/dev/null 2>&1; then
      item "SSH server support" "open-source tailscaled detected"
    else
      item "SSH server support" "GUI client only; server unsupported"
    fi
  fi
  health="$(tailscale status 2>/dev/null | sed -n '/^# Health check:/,$p' || true)"
  if [[ -n "$health" ]]; then
    warn "Tailscale health" "reported warnings"
    printf '%s\n' "$health" | sed 's/^/  /'
  else
    item "Health" "no CLI warnings"
  fi
else
  warn "Tailscale" "not installed"
fi

section "Summary"
item "Warnings" "$warnings"
if ((strict && warnings)); then
  exit 1
fi

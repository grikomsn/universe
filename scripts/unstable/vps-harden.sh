#!/usr/bin/env bash
set -Eeuo pipefail

action="${1:-status}"
if (($#)); then
  shift
fi
advertise_routes=""
drop_ssh=0

usage() {
  cat <<'EOF'
Usage:
  vps-harden.sh status
  vps-harden.sh apply [--advertise-routes LIST] [--drop-ssh]
  vps-harden.sh rollback

Hardens a Fedora Linux VPS managed over Tailscale:
  - enables IPv4/IPv6 forwarding via /etc/sysctl.d/99-tailscale.conf
  - optionally advertises subnet routes
  - firewalld FedoraServer zone: masquerade on, ICMP echo blocked,
    cockpit service removed; ssh service removed only with --drop-ssh

Run as the sudo-capable target user; the script invokes sudo itself.
Run scripts/unstable/ssh-server.sh apply first so native sshd stays
reachable with key-only auth. Firewall changes are applied at runtime
first and persisted only after you verify a fresh tailnet login; if
you decline the verification prompt, runtime firewall changes revert.
Rollback reverses exactly what apply persisted, using a state file.
EOF
}

while (($#)); do
  case "$1" in
  --advertise-routes)
    advertise_routes="${2:?--advertise-routes requires a value}"
    shift 2
    ;;
  --drop-ssh)
    drop_ssh=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

case "$action" in
status | apply | rollback) ;;
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
  echo "Linux only." >&2
  exit 1
}
if (($EUID == 0)); then
  echo "Run as your sudo-capable user, not root; this script invokes sudo itself." >&2
  exit 1
fi

command -v tailscale >/dev/null 2>&1 || {
  echo "tailscale CLI is not installed." >&2
  exit 1
}
command -v firewall-cmd >/dev/null 2>&1 || {
  echo "firewalld (firewall-cmd) is not installed." >&2
  exit 1
}

zone="FedoraServer"
sysctl_conf="/etc/sysctl.d/99-tailscale.conf"
sysctl_backup="${sysctl_conf}.before-universe"
state_file="/var/lib/universe-vps-harden.state"

confirm() {
  local expected="$1"
  local response
  printf 'Type %s to continue: ' "$expected"
  read -r response
  [[ "$response" == "$expected" ]]
}

runssh_pref() {
  tailscale debug prefs 2>/dev/null |
    awk -F': ' '/"RunSSH"/ {gsub(/[ ,]/, "", $2); print $2; exit}'
}

advertised_routes_now() {
  tailscale debug prefs 2>/dev/null |
    awk '
/"AdvertiseRoutes"/ {inlist = 1; next}
inlist && /\],?$/ {exit}
inlist {
  gsub(/[", \t]/, "")
  if ($0 != "") print
}
' |
    paste -sd ',' -
}

require_sudo() {
  sudo -n true 2>/dev/null || sudo -v
}

zone_has_service() {
  sudo firewall-cmd --zone="$zone" --list-services 2>/dev/null | tr ' ' '\n' | grep -Fxq "$1"
}

zone_has_icmp_block() {
  sudo firewall-cmd --zone="$zone" --list-icmp-blocks 2>/dev/null | tr ' ' '\n' | grep -Fxq "$1"
}

zone_masquerade() {
  # --query-masquerade prints yes/no on stdout; keep the socket clean and
  # rely on the exit code alone.
  sudo firewall-cmd --zone="$zone" --query-masquerade >/dev/null 2>&1
}

write_state() {
  local removed_services="$1"
  local masquerade_before="$2"
  local advertise_before="$3"
  local sysctl_had_file="$4"
  local temporary_state
  temporary_state="$(mktemp)"
  cat >"$temporary_state" <<EOF
# Managed by universe/scripts/unstable/vps-harden.sh
removed_services="$removed_services"
masquerade_before="$masquerade_before"
advertise_before="$advertise_before"
sysctl_had_file="$sysctl_had_file"
EOF
  sudo install -d -m 755 "$(dirname "$state_file")"
  sudo install -o root -g root -m 600 "$temporary_state" "$state_file"
  rm -f -- "$temporary_state"
}

apply_sysctl() {
  local had_file=0
  if sudo test -e "$sysctl_backup"; then
    had_file=1
  elif sudo test -e "$sysctl_conf"; then
    sudo cp -a "$sysctl_conf" "$sysctl_backup"
    had_file=1
  fi
  if ! sudo grep -q '^net\.ipv4\.ip_forward = 1$' "$sysctl_conf" 2>/dev/null; then
    echo 'net.ipv4.ip_forward = 1' | sudo tee -a "$sysctl_conf" >/dev/null
  fi
  if ! sudo grep -q '^net\.ipv6\.conf\.all\.forwarding = 1$' "$sysctl_conf" 2>/dev/null; then
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a "$sysctl_conf" >/dev/null
  fi
  sudo sysctl -p "$sysctl_conf" >/dev/null
  printf '%s' "$had_file"
}

apply_firewall_runtime() {
  local masquerade_before removed_services=""
  masquerade_before="$(zone_masquerade && printf yes || printf no)"
  if [[ "$masquerade_before" == "no" ]]; then
    sudo firewall-cmd --zone="$zone" --add-masquerade >/dev/null
  fi
  if ! zone_has_icmp_block echo-request; then
    sudo firewall-cmd --zone="$zone" --add-icmp-block=echo-request >/dev/null
  fi
  local service
  local unwanted_services=(cockpit)
  for service in "${unwanted_services[@]}"; do
    if zone_has_service "$service"; then
      sudo firewall-cmd --zone="$zone" --remove-service="$service" >/dev/null
      removed_services+=" $service"
    fi
  done
  if [[ "$drop_ssh" == "1" ]]; then
    if zone_has_service ssh; then
      sudo firewall-cmd --zone="$zone" --remove-service=ssh >/dev/null
      removed_services+=" ssh"
    fi
  fi
  printf '%s|%s' "${removed_services# }" "$masquerade_before"
}

revert_firewall_runtime() {
  local removed_services="$1"
  local masquerade_before="$2"
  local service
  for service in $removed_services; do
    sudo firewall-cmd --zone="$zone" --add-service="$service" >/dev/null
  done
  if zone_has_icmp_block echo-request; then
    sudo firewall-cmd --zone="$zone" --remove-icmp-block=echo-request >/dev/null
  fi
  if [[ "$masquerade_before" == "no" ]] && zone_masquerade; then
    sudo firewall-cmd --zone="$zone" --remove-masquerade >/dev/null
  fi
}

apply_routes() {
  local advertise_before merged
  advertise_before="$(advertised_routes_now)"
  if [[ -n "$advertise_routes" ]]; then
    # tailscale --advertise-routes replaces the list; merge with existing
    # advertisements (including exit-node default routes) instead of dropping them.
    if [[ -n "$advertise_before" ]]; then
      merged="$(printf '%s\n%s\n' "$advertise_before" "$advertise_routes" | tr ',' '\n' | awk '!seen[$0]++ && $0 != ""' | paste -sd ',' -)"
    else
      merged="$advertise_routes"
    fi
    if [[ "$merged" != "$advertise_before" ]]; then
      sudo tailscale set --advertise-routes="$merged"
    fi
  fi
  printf '%s' "$advertise_before"
}

status_report() {
  printf 'OS:                %s\n' "$(uname -s)"
  printf 'Tailscale RunSSH:  %s\n' "$(runssh_pref || printf 'unknown')"
  printf 'Advertised routes: %s\n' "$(advertised_routes_now || printf 'unknown')"
  printf 'ip_forward:        %s\n' "$(sysctl -n net.ipv4.ip_forward 2>/dev/null || printf 'unknown')"
  printf 'ipv6 forwarding:   %s\n' "$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null || printf 'unknown')"
  printf 'Managed sysctl:    '
  sudo test -e "$sysctl_conf" && printf '%s\n' "$sysctl_conf" || printf 'absent\n'
  printf 'Zone %s:\n' "$zone"
  sudo firewall-cmd --zone="$zone" --list-all 2>/dev/null || printf '  unavailable\n'
  printf 'State file:        '
  sudo test -e "$state_file" && printf '%s\n' "$state_file" || printf 'absent\n'
  printf 'Health:\n'
  tailscale status 2>/dev/null | sed -n '/^# Health check:/,$p' || true
}

apply_policy() {
  require_sudo
  if [[ "$(runssh_pref)" != "true" ]]; then
    echo "Tailscale SSH (RunSSH) is not enabled; refusing firewall lockdown." >&2
    echo "Run scripts/unstable/tailscale-ssh.sh enable first so the tailnet stays reachable." >&2
    exit 1
  fi
  if ! sudo firewall-cmd --zone="$zone" --list-all >/dev/null 2>&1; then
    echo "Zone $zone not found; adjust the zone variable." >&2
    exit 1
  fi
  if [[ "$drop_ssh" == "1" ]]; then
    echo "--drop-ssh removes the ssh service from zone $zone; access is then"
    echo "Tailscale SSH plus key-only native sshd (ensure ssh-server.sh was applied)."
  fi
  confirm APPLY || exit 1

  local sysctl_had_file advertise_before firewall_state removed_services masquerade_before
  sysctl_had_file="$(apply_sysctl)"
  advertise_before="$(apply_routes)"
  firewall_state="$(apply_firewall_runtime)"
  removed_services="${firewall_state%%|*}"
  masquerade_before="${firewall_state##*|}"

  echo
  echo "Runtime changes applied. Before persisting, open a NEW tailnet login"
  echo "and confirm it works; public ping/cockpit$([[ "$drop_ssh" == 1 ]] && printf ' and ssh') are now blocked."
  if confirm VERIFY; then
    sudo firewall-cmd --runtime-to-permanent >/dev/null
    write_state "$removed_services" "$masquerade_before" "$advertise_before" "$sysctl_had_file"
    echo "Persisted. State recorded in $state_file."
  else
    revert_firewall_runtime "$removed_services" "$masquerade_before"
    echo "Verification declined; runtime firewall changes reverted." >&2
    echo "Sysctl and route changes remain; rerun apply to retry the firewall step." >&2
    exit 1
  fi
  status_report
}

rollback_policy() {
  require_sudo
  if ! sudo test -e "$state_file"; then
    echo "No managed state found: $state_file" >&2
    exit 1
  fi
  confirm ROLLBACK || exit 1
  # shellcheck source=/dev/null
  local removed_services masquerade_before advertise_before sysctl_had_file
  removed_services="$(sudo sed -n 's/^removed_services="\?\(.*\)"\?$/\1/p' "$state_file")"
  masquerade_before="$(sudo sed -n 's/^masquerade_before="\?\(.*\)"\?$/\1/p' "$state_file")"
  advertise_before="$(sudo sed -n 's/^advertise_before="\?\(.*\)"\?$/\1/p' "$state_file")"
  sysctl_had_file="$(sudo sed -n 's/^sysctl_had_file="\?\(.*\)"\?$/\1/p' "$state_file")"

  revert_firewall_runtime "$removed_services" "$masquerade_before"
  sudo firewall-cmd --runtime-to-permanent >/dev/null

  if [[ -n "$advertise_before" ]]; then
    sudo tailscale set --advertise-routes="$advertise_before"
  else
    sudo tailscale set --advertise-routes=
  fi

  if [[ "$sysctl_had_file" == "1" && "$(sudo test -e "$sysctl_backup" && printf yes || printf no)" == "yes" ]]; then
    sudo mv -f "$sysctl_backup" "$sysctl_conf"
    sudo sysctl -p "$sysctl_conf" >/dev/null
  else
    sudo rm -f "$sysctl_conf"
    sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null
    sudo sysctl -w net.ipv6.conf.all.forwarding=0 >/dev/null
  fi

  sudo rm -f "$state_file"
  echo "Previous configuration restored."
  status_report
}

case "$action" in
status) status_report ;;
apply) apply_policy ;;
rollback) rollback_policy ;;
esac

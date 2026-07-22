#!/usr/bin/env bash

set -Eeuo pipefail

os_name="$(uname -s)"
action="${1:-status}"
if (($#)); then
  shift
fi
target_user="$(id -un)"
public_key_file=""

usage() {
  cat <<'EOF'
Usage:
  ssh-server.sh status [--user USER]
  ssh-server.sh apply [--user USER] [--public-key PATH]
  ssh-server.sh rollback [--user USER]

Experimental key-only OpenSSH setup for Fedora Linux and macOS Remote Login.
Run as the target user; the script invokes sudo for system changes.
EOF
}

while (($#)); do
  case "$1" in
  --user)
    target_user="${2:?--user requires a value}"
    shift 2
    ;;
  --public-key)
    public_key_file="${2:?--public-key requires a value}"
    shift 2
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

account_record="$(getent passwd "$target_user" 2>/dev/null || true)"
if [[ -n "$account_record" ]]; then
  target_home="$(printf '%s\n' "$account_record" | cut -d: -f6)"
elif [[ "$os_name" == "Darwin" ]]; then
  target_home="$(dscl . -read "/Users/$target_user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
else
  echo "Unable to resolve account: $target_user" >&2
  exit 1
fi

public_key_file="${public_key_file:-$target_home/.ssh/id_ed25519.pub}"
authorized_keys_file="$target_home/.ssh/authorized_keys"
drop_in_dir="/etc/ssh/sshd_config.d"
drop_in_file="$drop_in_dir/00-universe-key-only.conf"
backup_file="$drop_in_file.before-universe"
created_marker="$drop_in_file.created-by-universe"
service_marker="$drop_in_file.enabled-service-by-universe"

if [[ "$os_name" == "Darwin" ]]; then
  platform_sshd="/usr/sbin/sshd"
  system_group="wheel"
else
  platform_sshd="/usr/sbin/sshd"
  [[ -x "$platform_sshd" ]] || platform_sshd="$(command -v sshd 2>/dev/null || true)"
  system_group="root"
fi

confirm() {
  local expected="$1"
  local response
  printf 'Type %s to continue: ' "$expected"
  read -r response
  [[ "$response" == "$expected" ]]
}

require_apply_context() {
  if [[ $EUID -eq 0 ]]; then
    echo "Run as $target_user, not through sudo; this script invokes sudo itself." >&2
    exit 1
  fi
  if [[ "$(id -un)" != "$target_user" ]]; then
    echo "Run as the target account: $target_user" >&2
    exit 1
  fi
  [[ -x "$platform_sshd" ]] || {
    echo "Platform sshd not found." >&2
    exit 1
  }
  [[ -s "$public_key_file" ]] || {
    echo "Public key not found: $public_key_file" >&2
    exit 1
  }
  ssh-keygen -lf "$public_key_file"
  if [[ "$(awk 'NF {count++} END {print count + 0}' "$public_key_file")" != "1" ]]; then
    echo "Public key file must contain exactly one non-empty key line." >&2
    exit 1
  fi
  sudo -v
}

native_service_state() {
  local state
  if [[ "$os_name" == "Linux" ]]; then
    state="$(systemctl is-active sshd.service 2>/dev/null || true)"
    printf '%s' "${state:-inactive}"
  elif launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
    printf 'loaded'
  else
    printf 'not loaded'
  fi
}

effective_value() {
  local key="$1"
  sudo "$platform_sshd" -T -C "user=$target_user,host=$(hostname),addr=127.0.0.1" |
    awk -v key="$key" '$1 == key {$1 = ""; sub(/^ /, ""); print; exit}'
}

status_policy() {
  printf 'OS:             %s\n' "$os_name"
  printf 'Target user:    %s\n' "$target_user"
  printf 'Target home:    %s\n' "$target_home"
  printf 'Platform sshd:  %s\n' "$platform_sshd"
  printf 'Native service: %s\n' "$(native_service_state)"
  printf 'Public key:     %s\n' "$public_key_file"
  [[ -f "$public_key_file" ]] && ssh-keygen -lf "$public_key_file" || true
  printf 'Authorized:     '
  if [[ -f "$authorized_keys_file" && -f "$public_key_file" ]] && grep -Fqx -- "$(<"$public_key_file")" "$authorized_keys_file"; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
  printf 'Managed policy: '
  if sudo -n test -f "$drop_in_file" 2>/dev/null; then
    printf '%s\n' "$drop_in_file"
  else
    printf 'not readable or absent\n'
  fi
  if sudo -n true 2>/dev/null; then
    for key in pubkeyauthentication authenticationmethods passwordauthentication \
      kbdinteractiveauthentication permitrootlogin allowusers; do
      printf 'Effective %-23s %s\n' "$key" "$(effective_value "$key")"
    done
  else
    printf 'Effective policy: requires a cached sudo credential\n'
  fi
}

install_authorized_key() {
  local public_key
  public_key="$(<"$public_key_file")"
  install -d -m 700 "$target_home/.ssh"
  if [[ ! -e "$authorized_keys_file" ]]; then
    install -m 600 /dev/null "$authorized_keys_file"
  else
    chmod 600 "$authorized_keys_file"
  fi
  if ! grep -Fqx -- "$public_key" "$authorized_keys_file"; then
    printf '%s\n' "$public_key" >>"$authorized_keys_file"
  fi
  if [[ "$os_name" == "Linux" ]] && command -v restorecon >/dev/null 2>&1; then
    sudo restorecon -RF "$target_home/.ssh"
  fi
}

write_policy() {
  local temporary_config
  temporary_config="$(mktemp)"
  cat >"$temporary_config" <<EOF
# Managed by universe/scripts/unstable/ssh-server.sh
PubkeyAuthentication yes
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
GSSAPIAuthentication no
HostbasedAuthentication no
AllowUsers $target_user
EOF

  sudo install -d -m 755 "$drop_in_dir"
  if sudo test -e "$drop_in_file" && ! sudo test -e "$created_marker" && ! sudo test -e "$backup_file"; then
    sudo cp -a "$drop_in_file" "$backup_file"
  elif ! sudo test -e "$drop_in_file"; then
    sudo install -o root -g "$system_group" -m 600 /dev/null "$created_marker"
  fi
  sudo install -o root -g "$system_group" -m 600 "$temporary_config" "$drop_in_file"
  rm -f -- "$temporary_config"
  if [[ "$os_name" == "Linux" ]] && command -v restorecon >/dev/null 2>&1; then
    sudo restorecon "$drop_in_file"
  fi
}

assert_policy() {
  local failures=0
  local key expected actual
  while read -r key expected; do
    actual="$(effective_value "$key")"
    printf '%-32s expected=%-10s actual=%s\n' "$key" "$expected" "$actual"
    [[ "$actual" == "$expected" ]] || failures=1
  done <<EOF
pubkeyauthentication yes
authenticationmethods publickey
passwordauthentication no
kbdinteractiveauthentication no
permitemptypasswords no
permitrootlogin no
gssapiauthentication no
hostbasedauthentication no
allowusers $target_user
EOF
  ((failures == 0))
}

enable_service() {
  if [[ "$os_name" == "Linux" ]]; then
    if ! systemctl is-enabled sshd.service >/dev/null 2>&1 || ! systemctl is-active sshd.service >/dev/null 2>&1; then
      sudo install -o root -g root -m 600 /dev/null "$service_marker"
      if ! sudo systemctl enable --now sshd.service; then
        sudo rm -f -- "$service_marker"
        return 1
      fi
    else
      sudo systemctl reload sshd.service
    fi
  else
    if ! launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
      sudo install -o root -g wheel -m 600 /dev/null "$service_marker"
      if ! sudo /usr/sbin/systemsetup -setremotelogin on; then
        sudo rm -f -- "$service_marker"
        return 1
      fi
    fi
  fi
}

restore_policy() {
  if sudo test -e "$backup_file"; then
    sudo mv -f "$backup_file" "$drop_in_file"
    sudo rm -f -- "$created_marker"
  elif sudo test -e "$created_marker"; then
    sudo rm -f -- "$drop_in_file" "$created_marker"
  else
    echo "No managed rollback state found." >&2
    return 1
  fi
}

reload_after_rollback() {
  if [[ "$os_name" == "Linux" ]]; then
    if sudo test -e "$service_marker"; then
      sudo systemctl disable --now sshd.service
      sudo rm -f -- "$service_marker"
    else
      sudo systemctl reload sshd.service
    fi
  elif sudo test -e "$service_marker"; then
    sudo /usr/sbin/systemsetup -setremotelogin off
    sudo rm -f -- "$service_marker"
  fi
}

apply_policy() {
  require_apply_context
  echo "Keep this session open until a second key-authenticated login succeeds."
  confirm APPLY || exit 1
  install_authorized_key
  write_policy
  if ! sudo "$platform_sshd" -t || ! assert_policy; then
    echo "Validation failed; restoring prior policy." >&2
    restore_policy
    exit 1
  fi
  if ! enable_service; then
    echo "Service change failed; restoring prior policy." >&2
    restore_policy
    exit 1
  fi
  echo "Key-only SSH policy applied. Test a second connection before closing this one."
}

rollback_policy() {
  require_apply_context
  confirm ROLLBACK || exit 1
  restore_policy
  sudo "$platform_sshd" -t
  reload_after_rollback
  echo "Previous SSH policy restored; authorized_keys was retained."
}

case "$action" in
status) status_policy ;;
apply) apply_policy ;;
rollback) rollback_policy ;;
esac

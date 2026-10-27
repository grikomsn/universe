#!/usr/bin/env bash
set -euo pipefail

old_user=""
new_user=""

usage() {
  cat <<'EOF'
Usage:
  rename-user.sh --from OLD --to NEW

Rename a Linux login account and its primary group, move the home
directory, and update everything that referenced the old name:
  - /etc/subuid and /etc/subgid
  - sudoers.d drop-ins (visudo -c validated)
  - sshd_config.d AllowUsers (sshd -t, then reload)
  - SELinux labels on the new home (restorecon)
  - /var/spool/mail

Run as root (e.g. an SSH root session). All target-user processes
are terminated first; verify a fresh login for the new name (and
sudo) before closing your session.
EOF
}

while (($#)); do
  case "$1" in
  --from)
    old_user="${2:?--from requires a value}"
    shift 2
    ;;
  --to)
    new_user="${2:?--to requires a value}"
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

[[ -n "$old_user" && -n "$new_user" ]] || {
  usage >&2
  exit 2
}
[[ "$old_user" != "$new_user" ]] || {
  echo "--from and --to must differ." >&2
  exit 1
}
[[ "$(uname -s)" == "Linux" ]] || {
  echo "Linux only." >&2
  exit 1
}
[[ "$(id -u)" -eq 0 ]] || {
  echo "Run as root (sudo -i or an SSH root session)." >&2
  exit 1
}
getent passwd "$old_user" >/dev/null || {
  echo "No such user: $old_user" >&2
  exit 1
}
if getent passwd "$new_user" >/dev/null; then
  echo "Target user already exists: $new_user" >&2
  exit 1
fi

confirm() {
  local expected="$1"
  local response
  printf 'Type %s to continue: ' "$expected"
  read -r response
  [[ "$response" == "$expected" ]]
}

confirm RENAME || exit 1

echo "== terminating all $old_user processes"
loginctl terminate-user "$old_user" 2>/dev/null || true
pkill -u "$old_user" 2>/dev/null || true
sleep 2
pkill -9 -u "$old_user" 2>/dev/null || true
sleep 1
if ps -u "$old_user" --no-headers | grep -q .; then
  echo "Processes still running; refusing to continue:" >&2
  ps -u "$old_user" --no-headers >&2
  exit 1
fi

echo "== account rename"
usermod -l "$new_user" -d "/home/$new_user" -m "$old_user"
groupmod -n "$new_user" "$old_user"
sed -i "s/\b$old_user\b/$new_user/g" /etc/subuid /etc/subgid
getent passwd "$new_user"
id "$new_user"

echo "== sudoers"
for f in /etc/sudoers.d/*; do
  [[ -f "$f" ]] || continue
  sed -i "s/\b$old_user\b/$new_user/g" "$f"
done
visudo -c

echo "== sshd"
for f in /etc/ssh/sshd_config.d/*.conf; do
  [[ -f "$f" ]] || continue
  sed -i "s/\b$old_user\b/$new_user/g" "$f"
done
PATH="$PATH:/usr/sbin" sshd -t
systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true

echo "== selinux"
if command -v restorecon >/dev/null 2>&1; then
  restorecon -RF "/home/$new_user"
fi

echo "== mail spool"
if [[ -f "/var/spool/mail/$old_user" ]]; then
  mv "/var/spool/mail/$old_user" "/var/spool/mail/$new_user"
fi

echo "== cloud-init"
if [[ -f /etc/cloud/cloud.cfg ]]; then
  if grep -rn "\b$old_user\b" /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d/ 2>/dev/null; then
    echo "WARNING: cloud-init still references $old_user; edit the files above" >&2
    echo "WARNING or a future cloud-init run may recreate the old account." >&2
  else
    echo "(no cloud-init references to $old_user)"
  fi
else
  echo "(no /etc/cloud/cloud.cfg)"
fi

echo "== done; verify a fresh login for $new_user (and sudo) before closing this session"

#!/usr/bin/env bash

set -euo pipefail

# headless-x11.sh - run a virtual X11 display (Xvfb + openbox) as systemd user
# services on a headless Linux box, so GUI automation (agent-desktop, headed
# browsers) has a display to attach to. Only shells pick up DISPLAY, from the
# env file this writes (see .profile and conf.d/headless-x11.fish).

action="${1:-status}"
if (($#)); then
  shift
fi
display_num=99
screen_size="1920x1080x24"
force=0

unit_dir="$HOME/.config/systemd/user"
state_dir="$HOME/.local/state/headless-x11"
auth_file="$state_dir/Xauthority"
env_file="$state_dir/env"
xvfb_unit="headless-xvfb.service"
wm_unit="headless-openbox.service"

usage() {
  cat <<'EOF'
Usage:
  headless-x11.sh status
  headless-x11.sh register [--display N] [--size WxHxD] [--force]
  headless-x11.sh deregister

Runs Xvfb on :N (default :99) plus openbox as systemd user services, enables
linger so they start at boot, and writes DISPLAY, XAUTHORITY and
ACCESSIBILITY_ENABLED to ~/.local/state/headless-x11/env, which login shells
load when they have no display of their own. The display requires a private
Xauthority cookie, so other local users cannot connect. Re-running register
only restarts the display when its config changed.

The env stays out of the systemd user environment on purpose: D-Bus-activated
helpers such as the keyring unlock prompt would otherwise open invisibly on
the virtual display and hang whatever asked for them.

register refuses while a desktop session or display manager is running unless
--force. Linux only; installs packages with sudo.
EOF
}

while (($#)); do
  case "$1" in
  --display)
    display_num="${2:?--display requires a value}"
    display_num="${display_num#:}"
    shift 2
    ;;
  --size)
    screen_size="${2:?--size requires a value}"
    shift 2
    ;;
  --force)
    force=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "headless-x11.sh is Linux-only" >&2
  exit 1
fi

[[ "$display_num" =~ ^[0-9]+$ ]] || {
  echo "invalid display: $display_num" >&2
  exit 1
}
[[ "$screen_size" =~ ^[0-9]+x[0-9]+x[0-9]+$ ]] || {
  echo "invalid size: $screen_size (want WxHxD, e.g. 1920x1080x24)" >&2
  exit 1
}

socket="/tmp/.X11-unix/X$display_num"
changed=0

install_packages() {
  local bin missing=0
  for bin in Xvfb xauth xprop openbox; do
    command -v "$bin" >/dev/null || missing=1
  done
  ((missing)) || return 0
  if command -v dnf >/dev/null; then
    sudo dnf install -y xorg-x11-server-Xvfb xorg-x11-xauth xprop openbox
  elif command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y xvfb xauth x11-utils openbox
  else
    echo "no supported package manager; install Xvfb, xauth, xprop and openbox manually" >&2
    exit 1
  fi
}

has_graphical_session() {
  systemctl is-active --quiet display-manager.service 2>/dev/null && return 0
  local session type
  for session in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
    type="$(loginctl show-session "$session" -p Type --value 2>/dev/null || true)"
    [[ "$type" == "x11" || "$type" == "wayland" ]] && return 0
  done
  return 1
}

# X servers record their PID in /tmp/.X<N>-lock; a live PID that isn't our
# unit's means another server owns the display (a stale lock doesn't count).
display_taken() {
  local lock="/tmp/.X$display_num-lock" pid
  [[ -r "$lock" ]] || return 1
  pid="$(tr -d ' \n' <"$lock")"
  [[ -n "$pid" && -d "/proc/$pid" ]] || return 1
  [[ "$pid" != "$(systemctl --user show -p MainPID --value "$xvfb_unit" 2>/dev/null)" ]]
}

# Proves X answers, the cookie works and the window manager is up, all at once.
display_ready() {
  [[ -f "$env_file" ]] && command -v xprop >/dev/null || return 1
  (
    # shellcheck source=/dev/null
    set -a && . "$env_file" && set +a
    xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q 'window id'
  )
}

# Write a unit only when its content differs, so an unchanged re-register
# leaves the running display (and the apps on it) alone.
write_unit() {
  local path="$1" content="$2"
  if [[ -f "$path" && "$(cat "$path")" == "$content" ]]; then
    return
  fi
  printf '%s\n' "$content" >"$path"
  changed=1
}

ensure_cookie() {
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  if [[ -n "$(xauth -f "$auth_file" list ":$display_num" 2>/dev/null)" ]]; then
    return
  fi
  local cookie
  cookie="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  # Create it private up front so the cookie is never readable by others.
  (umask 077 && touch "$auth_file")
  xauth -q -f "$auth_file" add ":$display_num" MIT-MAGIC-COOKIE-1 "$cookie"
  # Add a FamilyWild (ffff) copy so the cookie survives hostname changes.
  xauth -q -f "$auth_file" nlist ":$display_num" | sed 's/^..../ffff/' |
    xauth -q -f "$auth_file" nmerge -
  # A running Xvfb only reads the cookie at startup.
  changed=1
}

write_units() {
  local xvfb_bin openbox_bin
  xvfb_bin="$(command -v Xvfb)"
  openbox_bin="$(command -v openbox)"
  mkdir -p "$unit_dir"

  # Wants= brings openbox back whenever Xvfb (re)starts, including after a crash.
  write_unit "$unit_dir/$xvfb_unit" "$(
    cat <<EOF
[Unit]
Description=Headless Xvfb display :$display_num
Wants=$wm_unit

[Service]
ExecStart=$xvfb_bin :$display_num -screen 0 $screen_size -nolisten tcp -auth $auth_file
Restart=on-failure

[Install]
WantedBy=default.target
EOF
  )"

  # Xvfb has no readiness notification: wait for its socket, and keep retrying
  # (no start limit) in case openbox races a restarting Xvfb. $$ is a literal $.
  write_unit "$unit_dir/$wm_unit" "$(
    cat <<EOF
[Unit]
Description=Headless openbox window manager on :$display_num
BindsTo=$xvfb_unit
After=$xvfb_unit
StartLimitIntervalSec=0

[Service]
Environment=DISPLAY=:$display_num
Environment=XAUTHORITY=$auth_file
ExecStartPre=/bin/sh -c 'for i in \$\$(seq 50); do [ -S $socket ] && exit 0; sleep 0.1; done; exit 1'
ExecStart=$openbox_bin
Restart=on-failure
RestartSec=1

[Install]
WantedBy=default.target
EOF
  )"

  # ACCESSIBILITY_ENABLED: without a desktop settings daemon, org.a11y.Status
  # IsEnabled stays false and Chromium/GTK apps never join the AT-SPI bus.
  cat >"$env_file" <<EOF
DISPLAY=:$display_num
XAUTHORITY=$auth_file
ACCESSIBILITY_ENABLED=1
EOF
}

unit_state() {
  systemctl --user is-active "$1" 2>/dev/null || true
}

cmd_status() {
  echo "xvfb unit:     $(unit_state "$xvfb_unit")"
  echo "openbox unit:  $(unit_state "$wm_unit")"
  if [[ -f "$env_file" ]]; then
    echo "env file:      $env_file ($(paste -sd' ' "$env_file"))"
  else
    echo "env file:      absent"
  fi
  if display_ready; then
    echo "display:       answering, window manager up"
  else
    echo "display:       not answering"
  fi
  echo "linger:        $(loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null || echo unknown)"
  echo "shell DISPLAY: ${DISPLAY:-unset}"
  if command -v agent-desktop >/dev/null && [[ -f "$env_file" ]]; then
    echo "agent-desktop: $(
      # shellcheck source=/dev/null
      set -a && . "$env_file" && set +a
      agent-desktop status 2>/dev/null |
        jq -c '{surfaces: .data.supported_surfaces, accessibility: .data.permissions.accessibility.state}' 2>/dev/null ||
        echo unavailable
    )"
  fi
}

cmd_register() {
  if has_graphical_session && ((!force)); then
    echo "a desktop session or display manager is running; use its display, or pass --force" >&2
    exit 1
  fi
  if display_taken; then
    echo "display :$display_num is owned by another X server (/tmp/.X$display_num-lock); pick --display N or stop it" >&2
    exit 1
  fi

  install_packages
  ensure_cookie
  write_units

  systemctl --user daemon-reload
  systemctl --user enable "$xvfb_unit" "$wm_unit"
  # Clear a start-limit failure from an earlier bad config; the probe below,
  # not systemctl's exit code, decides whether the display came up.
  systemctl --user reset-failed "$xvfb_unit" "$wm_unit" 2>/dev/null || true
  if ((changed)); then
    systemctl --user restart "$xvfb_unit" "$wm_unit" || true
  else
    systemctl --user start "$xvfb_unit" "$wm_unit" || true
  fi
  # Linger keeps the user manager (and these units) running without a login.
  if [[ "$(loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null)" != "yes" ]]; then
    loginctl enable-linger "$(id -un)" 2>/dev/null || sudo loginctl enable-linger "$(id -un)"
  fi

  local tries=50
  until display_ready || ((--tries == 0)); do
    sleep 0.2
  done
  if ! display_ready; then
    cmd_status
    echo "display :$display_num did not come up; see: journalctl --user -u $xvfb_unit -u $wm_unit" >&2
    exit 1
  fi

  cmd_status
  if ((changed)); then
    echo "registered :$display_num (restarted); open a new shell to pick up DISPLAY and XAUTHORITY"
  else
    echo "registered :$display_num (unchanged, left running)"
  fi
}

cmd_deregister() {
  systemctl --user disable --now "$wm_unit" "$xvfb_unit" 2>/dev/null || true
  rm -f "$unit_dir/$wm_unit" "$unit_dir/$xvfb_unit"
  rm -rf "$state_dir"
  systemctl --user daemon-reload
  # Packages and linger stay: other user services may rely on linger.
  cmd_status
  echo "deregistered; open a new shell to drop DISPLAY"
}

case "$action" in
status) cmd_status ;;
register) cmd_register ;;
deregister) cmd_deregister ;;
-h | --help | help) usage ;;
*)
  echo "Unknown action: $action" >&2
  usage >&2
  exit 1
  ;;
esac

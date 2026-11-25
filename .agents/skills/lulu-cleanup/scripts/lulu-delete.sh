#!/usr/bin/env bash
# Delete LuLu rules through its Rules window with agent-desktop, one filter at
# a time, with count checks so it can only remove rows the plan expects.
#
# Usage:
#   lulu-delete.sh window                    print the Rules window id, opening it
#                                            from the menu-bar item if needed
#   lulu-delete.sh run WIN FILTER COUNT      delete every deletable row FILTER shows
#   lulu-delete.sh plan WIN PLAN.tsv         run each "filter<TAB>count" line in order
#   lulu-delete.sh clear WIN                 empty the Filter Rules box
#
# A row is deletable only when its signer reads "Ad hoc" or "invalid/unsigned"
# (path-keyed rules). Signed rows a filter also shows are never touched. Before
# deleting, the visible deletable count must equal COUNT; after each delete it
# must drop by exactly one. Any mismatch stops with a non-zero exit.
#
# Exit codes: 2 count mismatch before deleting, 3 no Delete menu, 4 count drift
# after a delete or a failed snapshot, 5 window or filter box not found.
set -euo pipefail

ad() { agent-desktop "$@" 2>/dev/null; }

window_id() {
  ad list-windows --app LuLu | jq -r '[.data[]? | select(.title=="LuLu Rules") | .id][0] // empty'
}

cmd_window() {
  local w show
  w="$(window_id)"
  if [[ -z "$w" ]]; then
    # Menu-bar item: ... Rules > Show... ; take the first "Show..." after "Rules".
    show="$(ad snapshot --app LuLu --surface menu-bar-extras --compact |
      jq -r '[.. | objects | select(.role=="menuitem") | {r:.ref_id, n:.name}]
        | (map(.n) | index("Rules")) as $i
        | if $i == null then empty else (.[$i+1:] | map(select(.n=="Show..."))[0].r // empty) end')"
    [[ -n "$show" ]] || {
      echo "no LuLu menu-bar item with Rules > Show... to open the Rules window" >&2
      if plutil -extract noIconMode raw /Library/Objective-See/LuLu/preferences.plist 2>/dev/null | grep -qx true; then
        echo "LuLu runs with noIconMode on (no menu-bar icon); ask the user to open the Rules window" >&2
      fi
      exit 5
    }
    ad click "$show" >/dev/null
    for _ in 1 2 3 4 5; do
      sleep 1
      w="$(window_id)"
      [[ -n "$w" ]] && break
    done
  fi
  [[ -n "$w" ]] || {
    echo "LuLu Rules window did not open" >&2
    exit 5
  }
  echo "$w"
}

field() {
  ad snapshot --app LuLu --window-id "$1" --max-depth 3 |
    jq -r '[.. | objects | select(.name=="Filter Rules") | .ref_id][0] // empty'
}

# Top-level outline rows (window > scrollarea > outline > treeitem) whose
# signer marks them path-keyed, with the ref of their "list" (≡) menu button.
# Fails (instead of printing an empty list) when the snapshot does, so a
# failed read never passes for "no rows left".
rows() {
  local out
  for _ in 1 2 3; do
    out="$(ad snapshot --app LuLu --window-id "$1" --max-depth 6 --timeout-ms 8000 || true)"
    if jq -e '.ok == true' <<<"$out" >/dev/null 2>&1; then
      jq -c '[.data.tree.children[0].children[0].children[]?
        | select(.name? and (.name | test("\\(signer: (Ad hoc|invalid/unsigned)\\)$")))
        | {n: .name, b: ([.. | objects | select(.name=="list") | .ref_id][0])}]' <<<"$out"
      return 0
    fi
    sleep 0.5
  done
  echo "snapshot of the Rules window failed" >&2
  return 1
}

cmd_clear() {
  local f
  f="$(field "$1")"
  [[ -n "$f" ]] || {
    echo "Filter Rules box not found" >&2
    exit 5
  }
  ad clear "$f" >/dev/null || true
}

cmd_run() {
  local w="$1" filter="$2" expected="$3" f r n n2 b name menu i=0
  f="$(field "$w")"
  [[ -n "$f" ]] || {
    echo "Filter Rules box not found" >&2
    exit 5
  }
  ad clear "$f" >/dev/null || true
  # Headless typing is refused here and set-value doesn't trigger the filter,
  # so this one step uses real keyboard input (briefly takes focus).
  ad --headed type "$f" "$filter" >/dev/null
  sleep 0.6

  r="$(rows "$w")" || exit 4
  n="$(jq length <<<"$r")"
  echo "filter=$filter visible_deletable=$n expected=$expected"
  jq -r '.[].n' <<<"$r" | sed 's/^/   /'
  if [[ "$n" -ne "$expected" ]]; then
    echo "MISMATCH - stopping"
    exit 2
  fi

  while [[ "$n" -gt 0 ]]; do
    b="$(jq -r '.[0].b' <<<"$r")"
    name="$(jq -r '.[0].n' <<<"$r")"
    menu=""
    for _ in 1 2 3; do
      ad click "$b" >/dev/null || true
      sleep 0.3
      # One rule: "Delete Rule"; an app row holding several: "Delete Rules".
      menu="$(ad snapshot --app LuLu --surface menu --compact |
        jq -r '[.. | objects | select(.role=="menuitem" and (.name=="Delete Rule" or .name=="Delete Rules")) | .ref_id][0] // empty')"
      [[ -n "$menu" ]] && break
      r="$(rows "$w")" || exit 4
      b="$(jq -r '.[0].b' <<<"$r")"
    done
    if [[ -z "$menu" ]]; then
      echo "no Delete menu for $name - stopping"
      ad press escape >/dev/null || true
      exit 3
    fi
    ad click "$menu" >/dev/null # no confirmation dialog follows
    sleep 0.3
    r="$(rows "$w")" || exit 4
    n2="$(jq length <<<"$r")"
    if [[ "$n2" -ne $((n - 1)) ]]; then
      echo "count went $n -> $n2 after $name - stopping"
      exit 4
    fi
    n="$n2"
    i=$((i + 1))
  done
  echo "deleted $i"
}

cmd_plan() {
  local w="$1" plan="$2" filter count
  while IFS=$'\t' read -r filter count; do
    [[ -n "$filter" ]] || continue
    if ! cmd_run "$w" "$filter" "$count" </dev/null | grep -v '^   '; then
      echo "STOPPED at $filter"
      exit 1
    fi
  done <"$plan"
}

command -v agent-desktop >/dev/null || {
  echo "agent-desktop not installed" >&2
  exit 5
}
command -v jq >/dev/null || {
  echo "jq not installed" >&2
  exit 5
}

case "${1:-}" in
window) cmd_window ;;
run) cmd_run "$2" "$3" "$4" ;;
plan) cmd_plan "$2" "$3" ;;
clear) cmd_clear "$2" ;;
*)
  sed -n '2,17p' "$0"
  exit 2
  ;;
esac

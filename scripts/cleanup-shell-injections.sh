#!/usr/bin/env bash

set -euo pipefail

remove_section() {
  local file="$1"
  local start_pattern="$2"
  local end_pattern="$3"
  local real_file
  local temporary

  [[ -f "$file" ]] || return

  real_file="$(realpath "$file")"
  temporary="$(mktemp)"
  awk -v start="$start_pattern" -v end="$end_pattern" '
    $0 ~ start { skipping = 1; next }
    skipping && $0 ~ end { skipping = 0; next }
    !skipping { print }
  ' "$real_file" >"$temporary"

  if ! cmp -s "$real_file" "$temporary"; then
    cp "$temporary" "$real_file"
    echo "Removed injected shell configuration from $file"
  fi
  rm -f "$temporary"
}

remove_section \
  "$HOME/.profile" \
  '^# Added by LM Studio CLI \\(lms\\)$' \
  '^# End of LM Studio CLI section$'
remove_section \
  "$HOME/.config/fish/config.fish" \
  '^# Added by LM Studio CLI \\(lms\\)$' \
  '^# End of LM Studio CLI section$'
remove_section \
  "$HOME/.config/fish/config.fish" \
  '^# opencode$' \
  '^fish_add_path .*/\\.opencode/bin$'

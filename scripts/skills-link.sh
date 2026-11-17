#!/usr/bin/env bash

set -euo pipefail

# Link personal skills (~/.agents/skills, which ~/.claude/skills also reaches)
# into extra Claude config dirs, e.g. a work profile run with
# CLAUDE_CONFIG_DIR=~/.claude_work. Links go in one by one so the profile's own
# skills stay alongside. Skips `synced` (Claude's per-account skill sync) and
# dotfiles (e.g. .trash), never replaces a real file or dir, and prunes only
# its own links that went dangling. Idempotent — safe to re-run.
#
# Usage: skills-link.sh [CONFIG_DIR...]   (default: every ~/.claude_*/ dir)

src="$HOME/.agents/skills"

[[ -d "$src" ]] || {
  echo "no skills at $src" >&2
  exit 1
}

if [[ $# -gt 0 ]]; then
  targets=("$@")
else
  shopt -s nullglob
  targets=("$HOME"/.claude_*/)
  shopt -u nullglob
fi

[[ ${#targets[@]} -gt 0 ]] || {
  echo "no extra Claude config dirs (~/.claude_*); nothing to link"
  exit 0
}

for target in "${targets[@]}"; do
  dir="${target%/}/skills"
  mkdir -p "$dir"
  echo "linking skills into $dir"

  for path in "$src"/*; do
    name="$(basename "$path")"
    [[ "$name" == synced ]] && continue
    [[ -d "$path" ]] || continue
    dst="$dir/$name"
    if [[ -L "$dst" || ! -e "$dst" ]]; then
      ln -sfn "$src/$name" "$dst"
    else
      echo "  keeping $name (profile has its own)" >&2
    fi
  done

  for dst in "$dir"/*; do
    [[ -L "$dst" && ! -e "$dst" ]] || continue
    case "$(readlink "$dst")" in
    "$src"/*)
      echo "  pruning dangling $(basename "$dst")"
      rm "$dst"
      ;;
    esac
  done
done

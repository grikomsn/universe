#!/usr/bin/env bash

set -euo pipefail

# Restore skills-CLI-managed skills from .agents/.skill-lock.json.
# Skill dirs are gitignored (externally managed by `bunx skills`); the
# lockfile is the source of truth. Idempotent — safe to re-run.

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$repo/.agents/.skill-lock.json"

[[ -f "$lock" ]] || {
  echo "no lockfile at $lock" >&2
  exit 1
}

command -v bunx >/dev/null || {
  echo "bunx not found" >&2
  exit 1
}

jq -r '.skills | to_entries[] | "\(.key)\t\(.value.source)"' "$lock" |
  while IFS=$'\t' read -r skill source; do
    echo "restoring $skill from $source"
    bunx skills add "$source" -g -s "$skill" -y
  done

echo "skills restored: $(jq -r '.skills | keys | length' "$lock")"

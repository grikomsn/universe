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

if ! command -v bunx >/dev/null; then
  # Fresh boxes run bootstrap before the toolchain stage installs bun;
  # skip now and let a later invocation restore skills.
  echo "bunx not found; skipping skills restore (re-run after bun is installed)" >&2
  exit 0
fi

# </dev/null: the skills CLI consumes stdin, which would eat the remaining
# piped lockfile entries and silently stop the loop after the first skill.
installed=0
while IFS=$'\t' read -r skill source; do
  echo "restoring $skill from $source"
  bunx skills add "$source" -g -s "$skill" -y </dev/null &&
    [[ -f "$repo/.agents/skills/$skill/SKILL.md" ]] && installed=$((installed + 1)) ||
    echo "FAILED to restore $skill" >&2
done < <(jq -r '.skills | to_entries[] | "\(.key)\t\(.value.source)"' "$lock")

echo "skills installed: $installed"
[[ "$installed" -gt 0 ]]

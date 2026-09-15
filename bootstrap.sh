#!/usr/bin/env bash

# bootstrap.sh - runs automatically after `lnk init -r <url>` on a fresh clone.
# Keep it non-destructive and cross-platform: restores skills-CLI-managed
# skills from the lockfile and syncs editor extensions.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$repo/scripts/skills-restore.sh" ]]; then
  bash "$repo/scripts/skills-restore.sh" || true
fi

if [[ -f "$repo/scripts/vscode-sync.sh" ]]; then
  bash "$repo/scripts/vscode-sync.sh" || true
fi

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sync-agent-configs.sh <user@host>

Port the local (macOS) agent configs to a remote box over ssh:
  - pi: ported mcp.json (drops macOS-only servers), skills symlinks,
        npm package manifests + bun install, agents/, extensions/,
        models.json
  - dbhub.toml (chmod 600)
  - opencode: opencode.json + cli.json

Credentials (auth.json, mcp-auth.json) and machine state (sessions,
trust.json, caches) are intentionally NOT synced. Secret values are
carried verbatim over ssh/scp and never printed.

Dropped from mcp.json when porting:
  codex-cu  - macOS-only (ChatGPT.app computer-use paths)
  sonarqube - requires docker on the target
EOF
}

(($# == 1)) || {
  usage >&2
  exit 2
}
target="$1"
case "$target" in
-h | --help | help)
  usage
  exit 0
  ;;
esac
[[ "$target" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$ ]] || {
  echo "expected <user@host>" >&2
  exit 2
}

command -v jq >/dev/null || {
  echo "jq required locally." >&2
  exit 1
}

ssh -o BatchMode=yes -o ConnectTimeout=10 "$target" true || {
  echo "cannot reach $target" >&2
  exit 1
}

r_run() {
  printf '%s\n' "$*" | ssh -o BatchMode=yes "$target" bash -s
}

# --- pi mcp.json (ported; secrets carried verbatim, never printed) ----------
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
jq 'del(.mcpServers["codex-cu"], .mcpServers["sonarqube"])' "$HOME/.pi/agent/mcp.json" >"$tmp"
scp -q "$tmp" "$target:.pi/agent/mcp.json"
r_run 'chmod 600 ~/.pi/agent/mcp.json'

# --- skills: recreate symlinks to ~/.agents/skills (already lnk-synced) -----
r_run 'mkdir -p ~/.pi/agent/skills'
for skill in ~/.pi/agent/skills/*; do
  [[ -e "$skill" ]] || continue
  name="$(basename "$skill")"
  r_run "ln -sfn ~/.agents/skills/$name ~/.pi/agent/skills/$name"
done

# --- pi npm packages: manifests only; bun install rebuilds node_modules -----
r_run 'mkdir -p ~/.pi/agent/npm'
scp -q ~/.pi/agent/npm/package.json ~/.pi/agent/npm/package-lock.json "$target:.pi/agent/npm/"
if ! r_run 'cd ~/.pi/agent/npm && ~/.bun/bin/bun install'; then
  echo "warn: remote bun install failed (native build deps?)" >&2
fi

# --- small configs -----------------------------------------------------------
r_run 'mkdir -p ~/.pi/agent/agents ~/.pi/agent/extensions ~/.config/opencode'
[[ -f ~/.pi/agent/agents/Explore.md ]] && scp -q ~/.pi/agent/agents/Explore.md "$target:.pi/agent/agents/"
for ext in ~/.pi/agent/extensions/*; do
  [[ -e "$ext" ]] && scp -q "$ext" "$target:.pi/agent/extensions/"
done
[[ -f ~/.pi/agent/models.json ]] && scp -q ~/.pi/agent/models.json "$target:.pi/agent/models.json"
[[ -f ~/dbhub.toml ]] && {
  scp -q ~/dbhub.toml "$target:dbhub.toml"
  r_run 'chmod 600 ~/dbhub.toml'
}
[[ -f ~/.config/opencode/opencode.json ]] && scp -q ~/.config/opencode/opencode.json ~/.config/opencode/cli.json "$target:.config/opencode/"

echo "agent configs synced to $target"

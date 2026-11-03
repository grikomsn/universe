# Fleet

Entrypoint for managing the machine fleet: the local darwin laptop plus remote
linux boxes on a Tailscale tailnet, reached over ssh or Rex.

Invoke the `fleet` skill (`/fleet <task>`, manual only) from any harness; it
lives in `.agents/skills/fleet/`, which `~/.agents/skills` and
`~/.claude/skills` link to.

This repo is public. Keep hostnames, tailnet names, IPs and secrets out of it;
discover them at runtime.

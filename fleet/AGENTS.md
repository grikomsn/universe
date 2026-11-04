# Fleet

Entrypoint for managing the machine fleet: the local darwin laptop plus remote
linux boxes on a Tailscale tailnet, reached over ssh or Rex.

Invoke the `fleet` skill (`/fleet <task>`, manual only) from any harness; it
lives in `fleet/skill/`, linked at `.agents/skills/fleet` (a tracked symlink),
which `~/.agents/skills` and `~/.claude/skills` reach through their links
into this repo.

Private machine inventory lives in `fleet/fleet.toml` (git-ignored): main
machines, real hostnames, tailnet names, rex node aliases. `fleet/fleet.toml`
is a copy of the sanitized, tracked `fleet/fleet.example.toml`; each machine
keeps its own. Read it when a task needs names; never paste its contents
into commits, scratchpads or other repos.

This repo is public. Keep hostnames, tailnet names, IPs and secrets out of
commits; `fleet/fleet.toml` is the one ignored place for them. Discover
everything else at runtime.

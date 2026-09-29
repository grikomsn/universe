# Fleet

Entrypoint for managing the machine fleet: the local darwin laptop plus remote
linux boxes.

## Layout

- `.agents/skills/` — skills scoped to fleet work
  - `boxes-sync-mcp` — syncing/auditing MCP server configs across machines
    and harnesses (hand-written)
  - `herdr` — controlling herdr panes, agents, and workspaces, locally and
    over `herdr --machine <label>` (generated via `herdr --skill`; regenerate
    with `herdr --skill > fleet/.agents/skills/herdr/SKILL.md`)

## Conventions

- Skill dirs are gitignored except the ones force-included in `.gitignore`.
- `fleet/.agents/.skill-lock.json` is not used here; herdr's skill is
  generated, not restored from a source repo.
- Remote machines: resolve the ssh host via `herdr machine list --json`
  (saved herdr profiles) or the `fleet-boxes-sync-mcp` skill's resolution
  order. Never guess hostnames.
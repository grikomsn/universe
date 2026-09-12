---
name: boxes-sync-mcp
description: Use when syncing, auditing, or editing MCP server configs across the user's two machines (local darwin laptop + a remote linux box over ssh) and multiple harnesses. Covers config paths, per-harness JSON/TOML conventions, enable/disable flag semantics, and known drift traps. Deliberately omits server names, keys, hostnames, and absolute paths.
---

# Boxes sync MCP

Two machines: **local** (macOS) and **remote** (linux). Several harnesses with
MCP configs exist on both — treat any of their config files as the sync
surface, server names aside.

## Targeting the remote box

Never guess the remote hostname. Resolve it, in order:

1. Ask the user which ssh host to target if not stated in the current request.
2. Check `~/.ssh/config` for the obvious candidate host alias (a linux box
   matching the user's description; confirm with `ssh <alias> 'uname -s'` →
   expect `Linux`, vs local `Darwin`).
3. If a Tailscale-style hostname is mentioned in conversation, verify it
   resolves and connects with `ssh -o ConnectTimeout=10 -o BatchMode=yes`
   before using it for edits.

Once confirmed within a session, reuse it verbatim. Home directories differ
between machines — always use `~/...` or `$HOME`, never hardcoded absolute
user paths, when reading or writing remote configs.

## Config paths per harness

| Harness | local (darwin) | remote (linux) |
|---|---|---|
| opencode | `~/.config/opencode/opencode.json` | same path |
| pi | `~/.pi/agent/mcp.json` | same path |
| VS Code | `~/Library/Application Support/Code/User/mcp.json` | `~/.config/Code/User/mcp.json` |
| codex | `~/.codex/config.toml` | same path |

Discover current server entries by parsing each file (JSON keys under the
harness's container key; codex: `[mcp_servers.*]` TOML tables). Auth/credential
stores live outside these files and are intentionally machine-local — never
read, print, or sync them.

## Schema conventions

- **opencode** (JSON, v2 schema): container key `mcp` with entries nested under
  `mcp.servers` (v2 rejects server names placed directly under `mcp`). Each
  entry needs `type`: `"remote"` for URL-based (add `url`, optional `headers`
  object, optional `oauth: false`) or `"local"` for stdio (`command` as a
  **string array**, env vars under `environment`). Disable via `disabled: true`
  (there is no `enabled` flag in v2). Secrets use `{env:NAME}` substitution.
- **pi** (JSON): container key `mcpServers`. Inverted semantics: absence of
  `disabled` = enabled. Stdio `command` is a plain **string** + `args` array +
  optional `env` object.
- **VS Code** (JSON): container key `servers`. Type is `"http"` (not
  `"remote"`) or `"stdio"`. **No enable flag — presence = enabled**; disabling
  means deleting the entry. Entries may carry vendor-namespaced keys with extra
  fields (`gallery`, `version`) — that's valid, not drift.
- **codex** (TOML): tables `[mcp_servers.<name>]`. URL entries: `url` +
  `enabled = true|false`; headers live in a **separate sub-table**
  `[mcp_servers.<name>.http_headers]`. Stdio: `command` string + `args` +
  optional `[mcp_servers.<name>.env]`.

## Sync procedure

1. **Resolve ssh target** (see above) if the remote box is involved.
2. **Reconfirm state** on both boxes: parse every file in the table, print
   server name + enabled/disabled per harness. Never assume prior state.
3. **Compute the union** of server names across harnesses. When a name is
   missing from one harness, port it using that harness's schema convention —
   translate, don't copy raw JSON into TOML or vice versa.
4. **Enable/disable semantics differ per harness** (see above): opencode needs
   a `disabled` key *added* to turn off (absence = enabled); pi needs the
   `disabled` key *removed*; VS Code needs nothing (presence is enough).
5. **Edit surgically.** codex `config.toml` also holds unrelated state
   (project trust, plugins, app-managed runtime entries with
   platform-specific paths) — do targeted string replacements on the MCP
   tables only, never rewrite the file wholesale. Same caution for opencode:
   it strictly validates and rejects unknown top-level keys, and v2 rejects
   v1-shaped `mcp` layouts (server names directly under `mcp`).
6. **Remote edits**: the remote login shell is **fish** — heredocs and
   `<<EOF` redirects break there. Always wrap in
   `ssh <host> 'bash -s' <<'EOF' ... EOF`.
7. **Verify**: re-parse all files on both machines and diff the
   server+enabled map against expectations; report per-harness deltas.
8. **Remind user** to restart running sessions (harnesses load config once
   at startup; VS Code needs window reload).

## Known traps

- **Env-var / URL variants**: the same server may appear with different URLs
  across harnesses (e.g. regional endpoints). Before syncing, compare URLs
  across harnesses and pick the one already used by the most harnesses or
  the explicitly-preferred variant; normalize all copies.
- **Path style**: `~/...` works on both platforms; remote copies sometimes use
  absolute `$HOME/...` paths — prefer `~/` for portability.
- **JSON strictness**: the remote VS Code file historically contained a
  trailing comma (lenient-parsed by VS Code but breaks strict parsers). Keep
  all outputs strict-valid JSON.
- **App-managed entries**: harnesses may carry internal/runtime MCP entries
  not part of the user's sync set (e.g. codex's app-runtime servers). Leave
  them untouched even when they differ between machines.
- **Formatting drift between machines**: identical harnesses can serialize
  TOML differently (inline vs multi-line arrays). Prefer exact-string
  replacement of the minimal span over whole-file rewrites; if rewriting, use
  the language's standard dumper and verify by re-parse.
- **Secrets hygiene**: configs may embed API keys in headers or env blocks.
  When porting entries between files or machines, carry values verbatim but
  never echo them into output, logs, or summaries; refer to them positionally
  ("the api-key header").

## Canonical current state

All user-level MCP servers enabled across all harnesses on both machines,
except: codex lacks a couple of remote-transport entries (added to other
harnesses only), and codex's own app-runtime entries are machine-specific by
design. When asked to "sync X", enable/propagate X everywhere using the
conventions above.
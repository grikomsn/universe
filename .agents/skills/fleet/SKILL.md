---
name: fleet
description: Probe, diff, sync or run commands across the user's machines (macOS laptop plus Linux boxes on a Tailscale tailnet) over ssh or Rex; covers dotfile/harness/skill sync and MCP configs per harness.
argument-hint: "<task, e.g. diff claude settings on all machines>"
disable-model-invocation: true
---

# Fleet

The fleet is the local macOS laptop plus remote Linux boxes on a Tailscale
tailnet. Some of the boxes also run Rex. Every machine has this repo cloned at
`~/.config/lnk`, which symlinks the shared config into `$HOME`.

This repo is public. Discover hostnames, tailnet names, IPs and usernames at
runtime, and keep them out of this repo and its commits.

## Reach machines

1. **Find candidates.** Check `tailscale status --json`, using `.Self` and
   `.Peer[]` with their `.DNSName`, `.OS` and `.Online`. Also check `rex hosts
   list --json` and `rex hosts check`, and `Host` entries in `~/.ssh/config`.
   - "All my machines" means every reachable workstation.
   - If the user names one box and it's ambiguous, ask.
   - Skip appliances that close ssh, and report them as not probed.
2. **Probe each candidate** with `ssh -o ConnectTimeout=10 -o BatchMode=yes HOST
   'uname -s; hostname'`. Use the full MagicDNS name with the trailing dot
   stripped. Short `0x…`-style names get parsed as IPs.
3. **Choose a transport.**
   - **ssh answers:** use ssh.
   - **ssh refused, but a Rex host answers:** use Rex.
   - **Neither:** report the machine as not reachable.
   - **Local machine:** run commands directly.
4. **Dedupe.** One box can appear as an ssh host and also as one or more Rex
   hosts. Compare `/etc/machine-id` (macOS: `ioreg -rd1 -c
   IOPlatformExpertDevice`, field `IOPlatformUUID`) and the inode of
   `~/.claude.json` (`stat -c %i` on Linux, `stat -f %i` on macOS). Count a
   match once, and prefer ssh for it.

**ssh:** the remote login shell is fish, so bash syntax fails to parse there.
Always use one of these forms:

```sh
ssh HOST 'bash -s' <<'EOF'
...
EOF
ssh HOST bash -s -- ARG… <local-script.sh
```

**Rex:** there's no stdin, so don't push secrets through it. Kill only the
sessions you created.

```sh
out=$(rex -S LABEL new fleet-probe --json --keep-open -- bash -c "$(cat script.sh)" script ARG…)
s=$(jq -r .session_id <<<"$out"); b=$(jq -r '.initial_windows[0].block_ids[0]' <<<"$out")
rex -S LABEL wait -s "$s" "$b" --for 60s --json   # {"exit_code":N}; a timeout means still running
rex -S LABEL capture -s "$s" -b "$b" --trim --unwrap
rex -S LABEL kill "$s"
```

## Diff without leaking secrets

- **Never print config values raw.** Run `scripts/leaf-hashes.sh FILE
  [JQ_FILTER]`, from this skill's directory, on each machine and join the
  output locally. It prints `path<TAB>hash` per JSON leaf, accepts a quoted
  `~/` path, and tolerates trailing commas.
- **Print only values that differ** and aren't secrets, such as URLs, commands
  and flags. Name secrets by position ("the api-key header").
- **For whole trees,** hash with `find … -type f -print0 | xargs -0 shasum -a
  256` (`sha256sum` on Linux).
- **Inventory these trees:** `~/.claude`, `~/.claude.json`, `~/.pi/agent`,
  `~/.config/opencode`, `~/.codex/config.toml`, `~/.agents`.
- **Exclude:** credentials and auth stores, `sessions`, `projects`, `history*`,
  logs, caches, `shell-snapshots`, `todos`, `telemetry`, `node_modules`,
  `*.bak*`, `~/.fleet-removed-*`, `.DS_Store`.
- **Keep probe output** in the scratchpad. Delete temp files you put on remote
  boxes.

**Expected per-machine differences:** report these separately and don't fix
them.
- **Paths:** `/Users/…` on macOS vs `/home/…` on Linux.
- **opencode `service.json`:** holds a per-machine password.
- **Self-hosted services:** a service hosted on one box is `127.0.0.1` there
  and its tailnet name everywhere else.
- **`~/.claude.json` runtime state:** IDs, `projects`, counters, caches,
  onboarding, OAuth, `installMethod`, `autoUpdates*` and release-notes keys.
- **Platform-only files:** files that exist only on one platform.
- **Editor settings:** `darwin.lnk/` and `linux.lnk/` differ on purpose.

## Sync repo-backed config

Before anything else, check where the path comes from with `readlink`. These
are symlinks into the repo:
- `~/.claude/settings.json`
- `~/.pi/agent/settings.json`
- `~/.agents`
- `~/.claude/skills`
- every manifest entry

Two machines on the same repo commit match by definition. To change one:

1. **Check each box.** On each, check `git -C ~/.config/lnk log -1 --format=%h`
   and `status --short`.
2. **Edit the local repo once.** Commit only your own hunks; the user often has
   work in progress in the same file. Push only with the user's OK.
3. **Pull on each box** with `git -C ~/.config/lnk pull --ff-only`. If it
   refuses, report it; never reset.
4. **Run the follow-up step** that matches what changed:

   | Changed | Run |
   |---|---|
   | a manifest | `lnk pull` (`-H linux` on Linux) |
   | skill lock, or skill versions drift | `bash scripts/skills-restore.sh` (it downloads; say so) |
   | generated fish completions | `scripts/completions.sh` |

## MCP configs

| Harness | File (macOS / Linux) | Container | Enabled when |
|---|---|---|---|
| Claude Code | `~/.claude.json` | `mcpServers` | present |
| opencode v2 | `~/.config/opencode/opencode.json` | `mcp.servers` | no `disabled: true` |
| pi | `~/.pi/agent/mcp.json` | `mcpServers` | no `disabled` key |
| VS Code | `~/Library/Application Support/Code/User/mcp.json` / `~/.config/Code/User/mcp.json` | `servers` | present (delete to disable) |
| codex | `~/.codex/config.toml` | `[mcp_servers.<name>]` | `enabled = true` |

Shapes differ by harness, so translate entries between them; never copy one
raw.

- **Claude Code**
  - **stdio:** `command` (string) + `args` + `env`.
  - **URL:** `type: "http"` + `url` + `headers`.
  - Touch only `.mcpServers`; the rest of the file is runtime state. Verify
    with `claude mcp list`.
- **opencode**
  - **remote:** `type: "remote"` + `url` + `headers` (+ `oauth: false`).
  - **local:** `type: "local"`, with `command` as a **string array** and env
    under `environment`.
  - Server names go under `mcp.servers`, never directly under `mcp`. Unknown
    top-level keys are rejected.
- **pi:** `command` (string) + `args` + `env`.
- **VS Code**
  - Uses type `"http"` or `"stdio"`.
  - Vendor keys such as `gallery` and `version` are valid. The macOS file has
    had trailing commas before; write strict JSON.
- **codex**
  - **URL:** `url`, with headers in a `[mcp_servers.<name>.http_headers]`
    sub-table.
  - **stdio:** `command` + `args` + `[mcp_servers.<name>.env]`.
  - Edit only the MCP tables, by exact string replacement. The file also holds
    trust settings, plugins and app-managed servers; leave those alone.
- **Secrets:** carry values verbatim when porting, but compare them by hash.
  Write secret-bearing files over ssh stdin, never through Rex.

## Change safely

- **Reconfirm state** right before writing, and ask first unless the request
  already names the change and the target.
- **Back up** before changing anything.
  - **Edited files:** copy to `FILE.bak-fleet-<YYYYMMDD-HHMMSS>`.
  - **Removed files:** move them into
    `~/.fleet-removed-<topic>-<YYYYMMDD-HHMMSS>/`. Never `rm` them, and use
    `rmdir` only on directories that are already empty.
  - **Warn** when a backup holds secrets.
- **Before removing an extension or plugin,** grep that machine's harness
  configs for it. Remove config entries that only loaded it.
- **Edit surgically.** Use `jq` on a temp file, then `mv`, or exact string
  replacement. Never rewrite a whole config.
- **Verify afterwards.** Re-run the diff, and smoke-test the harness
  (`claude mcp list`, `opencode --version`, `pi --version`).
- **Report:**
  - Machines covered, with their transport and aliases, and any that were
    skipped and why.
  - Real drift first, then expected differences.
  - Every change and backup.
  - What you didn't check.
  - Remind the user that running sessions need a restart.

---
name: fleet
description: Probe, diff, sync or run commands across the user's machines (macOS laptop plus Linux boxes on a Tailscale tailnet) over ssh or Rex; covers dotfile/harness/skill sync, MCP configs per harness, and freeing disk space.
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

1. **Read the inventory first.** `~/.config/lnk/fleet/fleet.toml` (git-ignored,
   see `fleet/AGENTS.md`) lists the main machines under `[fleet].main` and each
   machine's `tailscale` name and `rex-node`.
   - "All my machines" means `[fleet].main`. Sync and clean up only those.
   - A `rex-node` is the Rex server's own tailnet identity on that machine,
     not another machine. Don't probe it or sync it; reach the host over ssh.
2. **Find other candidates** only when the inventory is missing or the user
   names a box it doesn't list. Check `tailscale status --json`, using `.Self`
   and `.Peer[]` with their `.DNSName`, `.OS` and `.Online`. Also check `rex
   hosts list --json` and `rex hosts check`, and `Host` entries in
   `~/.ssh/config`.
   - If the user names one box and it's ambiguous, ask.
   - Skip appliances that close ssh, and report them as not probed.
3. **Probe each candidate** with `ssh -o ConnectTimeout=10 -o BatchMode=yes HOST
   'uname -s; hostname'`. Use the full MagicDNS name with the trailing dot
   stripped. Short `0x…`-style names get parsed as IPs.
   - Tailscale SSH can stop and print "requires an additional check" with a
     login URL. `BatchMode` doesn't prevent this, and the call hangs until
     someone opens the URL. Show the user the URL and wait. Don't retry, and
     don't fan probes out in parallel, since each one hangs the same way.
4. **Choose a transport.**
   - **ssh answers:** use ssh.
   - **ssh refused, but a Rex host answers:** use Rex.
   - **Neither:** report the machine as not reachable.
   - **Local machine:** run commands directly.
5. **Dedupe.** One box can appear as an ssh host and also as one or more Rex
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
   | skills added or removed | `bash scripts/skills-link.sh` (links them into `~/.claude_*/skills`) |
   | generated fish completions | `scripts/completions.sh` |
   | `linux.lnk/.config/environment.d` | `systemctl --user daemon-reexec`, then restart the user services that need it (see below) |

**Environment variables** go in three places, because each kind of process
reads a different one:
- **fish:** `.config/fish/conf.d/02-profile.fish`.
- **POSIX login shells:** `.profile`, which mirrors the fish profile.
- **systemd user services on Linux,** such as `t3code.service` and its
  agents: `linux.lnk/.config/environment.d/*.conf`. These services read
  neither shell file.

A service sees a change only after `daemon-reexec` and its own restart. Check
with `systemctl --user show-environment`, then
`/proc/$(systemctl --user show -p MainPID --value UNIT)/environ`. Before
restarting `t3code.service`, check for running threads (T3 `t3_thread_list`
with that box's `environmentId` and `statuses: ["running", "starting",
"preparing", "queued"]`). A restart interrupts them.

## Free disk space

**Check `/tmp` before `/`.** On the Linux boxes, `/tmp` is a tmpfs mounted
with `usrquota`. When writes fail with "Disk quota exceeded", `df /` can still
show plenty of free space. Check `findmnt -no OPTIONS /tmp` and `quota -s`,
then `du` both `/tmp` and `/`. Use `sudo -n`: some boxes need a sudo password.
Membership in the `docker` group is enough for `docker` commands.

These were the largest items, and each one is removed differently. Moving a
large item to `~/.fleet-removed-*` on the same filesystem frees nothing, so
keep a cheap way to restore it instead:

| What | Check first | Remove |
|---|---|---|
| Caches in `/tmp`: `jest_rs`, `node-compile-cache`, `claude-<uid>/*` older than 2 days, leftover installers | `lsof +D /tmp`; deleted-but-open files (`lsof +L1`) | `mv` to `~/.fleet-removed-tmp-<ts>/`. That crosses filesystems, so it frees the quota. |
| T3 worktrees `~/.t3/worktrees/<project>/t3-*` left detached by delegated tasks | Clean `status --porcelain --ignored` apart from `node_modules`/build output; no process with its cwd inside; is HEAD on a branch (match by subject or `git patch-id`)? | `git update-ref refs/fleet-backup/<name> HEAD`, record name, sha and subject in the backup folder, then `git worktree remove` |
| Docker images and build cache | Images no container uses; images without `RepoDigests` were built on the box | `docker save \| gzip` the box-built ones, save `docker images` to the backup folder, then `docker image prune -a -f` and `docker builder prune -a -f`. Leave volumes unless asked. |
| Package caches (`~/.npm/_cacache`, uv, Playwright, Cypress) | none | Offer only. They rebuild on demand. |

**T3 threads survive a worktree removal.** Threads live in
`~/.t3/userdata/statev2.sqlite`, table `orchestration_v2_projection_threads`,
with the path at `payload_json.worktreePath`. A thread whose worktree is gone
still reads fine but can't run again until the worktree is recreated
(`git worktree add <path> refs/fleet-backup/<name>`). The boxes have no
`sqlite3` binary, so query read-only with `python3` and
`sqlite3.connect("file:…?mode=ro", uri=True)`, or use T3's `t3_thread_read`.

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

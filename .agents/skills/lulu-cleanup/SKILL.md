---
name: lulu-cleanup
description: Use when the user wants to clean up LuLu firewall rules on macOS, deleting stale and version-pinned entries through its Rules window and verifying against LuLu's rules file.
argument-hint: "[stale|versioned]"
disable-model-invocation: true
---

# LuLu cleanup

LuLu keys rules for ad hoc and unsigned binaries by path, so upgrades and
caches leave dead rules behind. Remove them. Scripts are in `scripts/`; usage
is in each script's header. `$WORK` is a scratch dir.

Rules:
- Read `/Library/Objective-See/LuLu/rules.plist` only. Delete only through
  the Rules window.
- Delete path-keyed rules only. Signed, Apple and block rules stay. The
  planner and the delete loop both enforce this.
- Deletes are instant and can't be undone. Never bypass the count checks.

## Steps

1. Plan:
   `python3 -I scripts/lulu-rules.py decode "$WORK" && python3 -I scripts/lulu-rules.py plan "$WORK" --scope <arg or versioned>`
   - Show the user the delete list and the kept list, and wait for an OK.
     Skip this on a repeat run, unless something new shows up.
   - If a kept path looks version-pinned, add it to `VERSIONED` (or to
     `BROAD_FILTERS` for a whole family), re-plan, and tell the user that the
     skill changed.
2. Get the window: `W=$(scripts/lulu-delete.sh window)`. This needs
   `agent-desktop` (load its skill). Ask before running `npm i -g
   agent-desktop`. If LuLu has no menu-bar icon (`noIconMode`), ask the user
   to open Rules.
3. Delete: run plan line 1 on its own with `lulu-delete.sh run "$W" <filter>
   <n>`, then the remaining lines with `lulu-delete.sh plan "$W" <rest.tsv>`.
   - Exit 2 (count mismatch before deleting): read the rows, then
     decode and plan again.
   - Exit 3 (menu didn't open): retry.
   - Exit 4 (count drift or failed snapshot): stop and investigate.
   - After a stop: `lulu-rules.py replan "$WORK"`, then continue.
4. Verify: `lulu-delete.sh clear "$W" && python3 -I scripts/lulu-rules.py verify "$WORK"`.
   A non-zero exit means something is wrong. Report it.

## Report

- Rule count before and after.
- What was removed, grouped by source.
- What was kept.
- LuLu will ask again about current versions of upgraded tools.

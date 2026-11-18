#!/usr/bin/env bash
# Delete every archived T3 thread on THIS machine through the running T3
# server's own `thread.delete` command (the same one the app's Delete button
# sends), so the event log stays the source of truth. The database is only
# ever opened read-only.
#
# Usage: t3-purge-archived.sh [--yes] [--limit N] [--check]
#   (no flags)  dry run: count archived threads and show what would go
#   --check     also issue a token and open the server connection, delete nothing
#   --yes       delete: one thread first, confirm it landed, then the rest
#   --limit N   delete at most N threads (with --yes)
#
# Remote: ssh HOST bash -s -- --yes <t3-purge-archived.sh
# Needs python3, and node >= 22 (built-in WebSocket) or bun.
# Honors T3CODE_HOME (default ~/.t3).
set -euo pipefail

yes=0 check=0 limit=0
while [[ $# -gt 0 ]]; do
  case "$1" in
  --yes) yes=1 ;;
  --check) check=1 ;;
  --limit)
    limit="$2"
    shift
    ;;
  -h | --help)
    sed -n '2,15p' "$0" 2>/dev/null || true
    exit 0
    ;;
  *)
    echo "unknown arg: $1" >&2
    exit 2
    ;;
  esac
  shift
done

t3home="${T3CODE_HOME:-$HOME/.t3}"
runtime="$t3home/userdata/server-runtime.json"
db="$t3home/userdata/statev2.sqlite"
[[ -r "$runtime" ]] || {
  echo "no T3 server runtime at $runtime" >&2
  exit 1
}
[[ -r "$db" ]] || {
  echo "no T3 database at $db" >&2
  exit 1
}

read -r port version < <(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["port"], d["serverVersion"])' "$runtime")

t3=""
for c in "$t3home/runtime/versions/$version/t3" "$t3home/bin/t3" "$(command -v t3 || true)"; do
  if [[ -n "$c" && -x "$c" ]]; then
    t3="$c"
    break
  fi
done
[[ -n "$t3" ]] || {
  echo "no t3 binary for server $version" >&2
  exit 1
}

runner=""
if command -v node >/dev/null && [[ "$(node -p 'process.versions.node.split(".")[0]')" -ge 22 ]]; then
  runner=node
elif command -v bun >/dev/null; then
  runner=bun
elif [[ -x "$HOME/.bun/bin/bun" ]]; then
  runner="$HOME/.bun/bin/bun"
fi

umask 077
tmp="$(mktemp -d)"
sid=""
cleanup() {
  if [[ -n "$sid" ]]; then
    "$t3" auth session revoke "$sid" >/dev/null 2>&1 && echo "revoked session" || echo "WARN: revoke failed; run: $t3 auth session revoke $sid" >&2
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

# Read-only queries against the projection table
q() {
  python3 -I - "$db" "$@" <<'PY'
import sqlite3, sys, collections
db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
cmd = sys.argv[2]
live = "archived_at IS NOT NULL AND deleted_at IS NULL"
T = "orchestration_v2_projection_threads"
if cmd == "count":
    print(db.execute(f"SELECT count(*) FROM {T} WHERE {live}").fetchone()[0])
elif cmd == "ids":
    for (tid,) in db.execute(f"SELECT thread_id FROM {T} WHERE {live} ORDER BY archived_at"):
        print(tid)
elif cmd == "summary":
    rows = db.execute(f"SELECT thread_id, archived_at FROM {T} WHERE {live}").fetchall()
    kinds = collections.Counter(
        "top-level" if ":" not in t else ":".join(t.split(":")[:2]) if t.startswith("thread:") else t.split(":")[0]
        for t, _ in rows)
    print(f"archived, not deleted: {len(rows)}")
    for k, n in kinds.most_common():
        print(f"  {k}: {n}")
    if rows:
        ts = sorted(a for _, a in rows)
        print(f"  archived between {ts[0][:16]} and {ts[-1][:16]}")
elif cmd == "deleted":
    r = db.execute(f"SELECT deleted_at FROM {T} WHERE thread_id = ?", (sys.argv[3],)).fetchone()
    print("yes" if r and r[0] else "no")
PY
}

echo "host=$(hostname) server=$version port=$port t3=$t3 runner=${runner:-none}"
t3ver="$("$t3" --version 2>/dev/null | tail -1 || true)"
[[ "$t3ver" == *"$version"* ]] || echo "WARN: t3 CLI reports '$t3ver', server is $version" >&2
before="$(q count)"
q summary

if [[ $yes -eq 0 && $check -eq 0 ]]; then
  echo "dry run: nothing deleted (pass --check to test the connection, --yes to delete)"
  exit 0
fi
[[ -n "$runner" ]] || {
  echo "need node >= 22 or bun" >&2
  exit 1
}
if [[ $yes -eq 1 && "$before" -eq 0 ]]; then
  echo "nothing to delete"
  exit 0
fi

cat >"$tmp/purge.mjs" <<'JS'
// purge.mjs <tokenFile> <port> [idsFile]; no idsFile = connection check only
import { readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
const [tokenFile, port, idsFile] = process.argv.slice(2);
const base = `http://127.0.0.1:${port}`;
const token = readFileSync(tokenFile, "utf8").trim();
const ids = idsFile ? readFileSync(idsFile, "utf8").split("\n").map((s) => s.trim()).filter(Boolean) : [];
const res = await fetch(`${base}/api/auth/websocket-ticket/rpc`, { method: "POST", headers: { authorization: `Bearer ${token}` } });
if (!res.ok) { console.error("ticket failed", res.status, (await res.text()).slice(0, 300)); process.exit(1); }
const { ticket } = await res.json();
// orchestrationProtocol=2 is required, else 426 orchestration_protocol_incompatible
const ws = new WebSocket(`ws://127.0.0.1:${port}/ws?wsTicket=${encodeURIComponent(ticket)}&orchestrationProtocol=2`);
let nextId = 0;
const pending = new Map();
ws.onmessage = (ev) => {
  let ms = JSON.parse(ev.data);
  if (!Array.isArray(ms)) ms = [ms];
  for (const m of ms) {
    if (m._tag === "Ping") { ws.send(JSON.stringify({ _tag: "Pong" })); continue; }
    if (m._tag === "Exit" && pending.has(m.requestId)) { pending.get(m.requestId).resolve(m.exit); pending.delete(m.requestId); }
  }
};
ws.onclose = () => { for (const p of pending.values()) p.reject(new Error("socket closed")); pending.clear(); };
const call = (tag, payload) => new Promise((resolve, reject) => {
  const id = String(nextId++);
  const t = setTimeout(() => { pending.delete(id); reject(new Error("timeout")); }, 30000);
  pending.set(id, { resolve: (x) => { clearTimeout(t); resolve(x); }, reject: (e) => { clearTimeout(t); reject(e); } });
  ws.send(JSON.stringify({ _tag: "Request", id, tag, payload, headers: [] }));
});
await new Promise((r, j) => { ws.onopen = r; ws.onerror = () => j(new Error("websocket failed to open")); });
if (!idsFile) { console.log("connection ok"); ws.close(); process.exit(0); }
let ok = 0, failed = 0;
for (const threadId of ids) {
  try {
    const exit = await call("orchestration.dispatchCommand", { type: "thread.delete", commandId: randomUUID(), threadId });
    if (exit._tag === "Success") ok++;
    else { failed++; console.error("FAIL", threadId, JSON.stringify(exit).slice(0, 300)); }
  } catch (e) { failed++; console.error("ERR", threadId, e.message); if (e.message === "socket closed") break; }
  if ((ok + failed) % 100 === 0) console.log(`  ${ok + failed}/${ids.length}`);
}
console.log(`deleted ${ok}, failed ${failed}`);
ws.close();
process.exit(failed ? 1 : 0);
JS

# Short-lived token scoped to threads only; it stays in $tmp and is revoked on exit
"$t3" auth session issue --scope orchestration:read --scope orchestration:operate \
  --ttl 1h --label t3-purge-archived --json >"$tmp/session.json"
sid="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["sessionId"])' "$tmp/session.json")"
python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$tmp/session.json" >"$tmp/token"
rm -f "$tmp/session.json"

if [[ $yes -eq 0 ]]; then
  "$runner" "$tmp/purge.mjs" "$tmp/token" "$port"
  exit 0
fi

q ids >"$tmp/ids"
if [[ "$limit" -gt 0 ]]; then
  head -n "$limit" "$tmp/ids" >"$tmp/ids.lim" && mv "$tmp/ids.lim" "$tmp/ids"
fi
head -n 1 "$tmp/ids" >"$tmp/first"
tail -n +2 "$tmp/ids" >"$tmp/rest"

echo "test: deleting 1 thread"
"$runner" "$tmp/purge.mjs" "$tmp/token" "$port" "$tmp/first"
[[ "$(q deleted "$(cat "$tmp/first")")" == yes ]] || {
  echo "test thread has no deleted_at; stopping" >&2
  exit 1
}
if [[ -s "$tmp/rest" ]]; then
  echo "deleting $(wc -l <"$tmp/rest" | tr -d ' ') more"
  "$runner" "$tmp/purge.mjs" "$tmp/token" "$port" "$tmp/rest" || true
fi

after="$(q count)"
echo "archived, not deleted: before=$before after=$after"

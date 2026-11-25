#!/usr/bin/env python3
"""Read-only helper for cleaning up LuLu firewall rules.

LuLu keeps its rules in /Library/Objective-See/LuLu/rules.plist, an
NSKeyedArchiver plist owned by its system extension. This script only ever
reads a copy of it; deletions go through LuLu's Rules window (lulu-delete.sh).

Usage (run with `python3 -I`):
  lulu-rules.py decode  DIR             copy rules.plist to DIR, decode to DIR/rules.json
  lulu-rules.py plan    DIR [--scope stale|versioned]
                                        pick rules to delete, write DIR/deletekeys.json
                                        and DIR/plan.tsv (filter<TAB>expected count)
  lulu-rules.py replan  DIR             after a partial run: keep the same delete list,
                                        rebuild DIR/plan.tsv against the live file
  lulu-rules.py verify  DIR             decode the live file to DIR/after.json and
                                        compare it with DIR/rules.json

Expected counts are app rows (one per rule key), which is what the Rules window
lists; a row holding several rules deletes them all at once.
"""

import json
import os
import plistlib
import re
import shutil
import sys

RULES_PLIST = "/Library/Objective-See/LuLu/rules.plist"

# Path fragments that pin a rule to one version or a throwaway build. A rule on
# such a path goes stale on the next upgrade or cleanup, so it is deleted even
# while the binary still exists.
VERSIONED = [
  r"/Cellar/[^/]+/\d",
  r"/Caskroom/[^/]+/\d",
  r"/\.cache/",
  r"portable-ruby/\d",
  r"node-versions/v\d",
  r"claude-code/\d",
  r"/_npx/",
  r"chrome-\d",
  r"chromium[_-][\w-]*\d{3,}",
  r"ms-playwright/webkit-\d",
  r"/node_modules/",
  r"\.vscode/extensions/[^/]+-\d",
  r"^/(private/)?var/folders/",
  r"^/(private/)?tmp/",
  r"/DerivedData/",
  r"/Versions/\d[\d.]+/",
  r"cpython-\d",
  r"mac-arm64/\d",
  r"/\d+\.\d+\.\d+/",
]

# Broad filters tried first, in order, before falling back to per-rule ones.
# A filter is used only if every path-keyed rule it matches is on the delete
# list, so it can never take out a rule that should stay.
BROAD_FILTERS = [
  "/Cellar/",
  "/Caskroom/",
  "portable-ruby",
  "/.cache/",
  "cpython-3",
  "node-versions",
  "/_npx/",
  "chrome-headless-shell/mac-arm64",
  ".agent-browser/browsers",
  ".vscode/extensions",
  "ms-playwright",
  "node_modules",
  "DerivedData",
  "/var/folders",
  f"/tmp/claude-{os.getuid()}",
]


def decode_file(src, dst):
  d = plistlib.load(open(src, "rb"))
  objs = d["$objects"]

  def ref(x):
    return objs[x.data] if isinstance(x, plistlib.UID) else x

  def dec(o):
    o = ref(o)
    if isinstance(o, dict):
      if "$class" in o:
        if "NS.keys" in o:
          return {str(dec(k)): dec(v) for k, v in zip(o["NS.keys"], o["NS.objects"])}
        if "NS.objects" in o:
          return [dec(v) for v in o["NS.objects"]]
        if "NS.string" in o:
          return o["NS.string"]
        if "NS.time" in o:
          return o["NS.time"]
        return {k: dec(v) for k, v in o.items() if k != "$class"}
      return o
    if o == "$null":
      return None
    if isinstance(o, bytes):
      return "<bytes>"
    return o

  rules = dec(d["$top"]["root"])
  json.dump(rules, open(dst, "w"), indent=1, default=str)
  return rules


def count(rules):
  return len(rules), sum(len(v["rules"]) for v in rules.values())


def short(p):
  return p.replace(os.path.expanduser("~"), "~")


def haystack(key, v):
  # Roughly what LuLu's Filter Rules box searches: key, paths, names, signer id.
  s = [key] + (v.get("paths") or [])
  for x in v["rules"]:
    s += [x.get("name") or "", x.get("path") or "", str((x.get("csInfo") or {}).get("signatureIdentifier", ""))]
  return "\n".join(s)


def cmd_decode(work):
  os.makedirs(work, exist_ok=True)
  shutil.copyfile(RULES_PLIST, os.path.join(work, "rules.plist"))
  r = decode_file(os.path.join(work, "rules.plist"), os.path.join(work, "rules.json"))
  apps, n = count(r)
  rows = [x for v in r.values() for x in v["rules"]]
  print(f"apps {apps} rules {n} | allow {sum(x['action'] == 1 for x in rows)} block {sum(x['action'] == 0 for x in rows)}")
  print("path-keyed (not tied to a signing identity):", sum(k.startswith("/") for k in r))
  print("stale (binary gone):", sum(k.startswith("/") and not os.path.exists(k) for k in r))


def build_filters(r, dk):
  """Pick filter strings that together cover every key in dk.

  Returns (plan, unplannable): plan is [(filter, expected rows)] in run order.
  """
  hay = {k: haystack(k, v) for k, v in r.items()}
  path_keys = [k for k in r if k.startswith("/")]

  def safe_hits(f):
    hit = [k for k in path_keys if f in hay[k]]
    return hit if hit and all(k in dk for k in hit) else None

  done, plan = set(), []

  def add(f, hit):
    new = [k for k in hit if k not in done]
    if new:
      plan.append((f, len(new)))
      done.update(new)

  for f in BROAD_FILTERS:
    hit = safe_hits(f)
    if hit:
      add(f, hit)
    elif any(f in hay[k] for k in path_keys if k in dk):
      print(f"skip broad filter {f!r}: it also matches rules to keep")

  unplannable = []
  for k in sorted(dk):
    if k in done:
      continue
    parts = k.rstrip("/").split("/")
    for i in range(1, len(parts)):
      f = "/".join(parts[-i:])
      hit = safe_hits(f)
      if hit:
        add(f, hit)
        break
    else:
      unplannable.append(k)
  return plan, unplannable


def write_plan(work, plan):
  with open(os.path.join(work, "plan.tsv"), "w") as fh:
    for f, n in plan:
      fh.write(f"{f}\t{n}\n")
  print("filters (filter -> expected deletable rows):")
  for f, n in plan:
    print(f"  {f!r:40} {n}")


def cmd_plan(work, scope):
  r = json.load(open(os.path.join(work, "rules.json")))
  dk = {}
  for k in r:
    # Only path-keyed rules. Signed apps are keyed by "identifier:signer" or a
    # bundle id and keep working across upgrades, so they are never touched.
    if not k.startswith("/"):
      continue
    stale = not os.path.exists(k)
    ver = scope == "versioned" and any(re.search(p, k) for p in VERSIONED)
    if stale or ver:
      dk[k] = "STALE" if stale else "ver"

  plan, unplannable = build_filters(r, dk)
  for k in unplannable:
    dk.pop(k)

  json.dump(sorted(dk), open(os.path.join(work, "deletekeys.json"), "w"), indent=1)

  print(f"delete: {len(dk)} apps, {sum(len(r[k]['rules']) for k in dk)} rules ({count(r)[1]} total)")
  for k in sorted(dk):
    print(f"  {dk[k]:5} {len(r[k]['rules'])} {short(k)[:150]}")
  write_plan(work, plan)
  if unplannable:
    print("NO SAFE FILTER (left out, delete by hand if wanted):")
    for k in unplannable:
      print("  ", short(k))
  print("path-keyed rules kept:")
  for k in r:
    if k.startswith("/") and k not in dk:
      print("  ", short(k)[:150])


def cmd_replan(work):
  shutil.copyfile(RULES_PLIST, os.path.join(work, "live.plist"))
  live = decode_file(os.path.join(work, "live.plist"), os.path.join(work, "live.json"))
  dk = {k for k in json.load(open(os.path.join(work, "deletekeys.json"))) if k in live}
  print(f"remaining to delete: {len(dk)} apps")
  plan, unplannable = build_filters(live, dk)
  write_plan(work, plan)
  if unplannable:
    print("NO SAFE FILTER:", [short(k) for k in unplannable])


def cmd_verify(work):
  shutil.copyfile(RULES_PLIST, os.path.join(work, "after.plist"))
  a = decode_file(os.path.join(work, "after.plist"), os.path.join(work, "after.json"))
  b = json.load(open(os.path.join(work, "rules.json")))
  dk = set(json.load(open(os.path.join(work, "deletekeys.json"))))
  (ba, br), (aa, ar) = count(b), count(a)
  still = [k for k in dk if k in a]
  unexpected = [k for k in b if k not in a and k not in dk]
  print(f"apps {ba} -> {aa} | rules {br} -> {ar}")
  print("delete keys still present:", [short(k) for k in still])
  print("unexpected removals:", [short(k) for k in unexpected])
  print("new since snapshot:", [short(k) for k in a if k not in b])
  print("stale paths remaining:", [short(k) for k in a if k.startswith("/") and not os.path.exists(k)])
  print("block rules kept:", [x["name"] for v in a.values() for x in v["rules"] if x["action"] == 0])
  sys.exit(1 if still or unexpected else 0)


def main():
  args = sys.argv[1:]
  if len(args) < 2 or args[0] not in ("decode", "plan", "replan", "verify"):
    print(__doc__.strip(), file=sys.stderr)
    sys.exit(2)
  cmd, work = args[0], args[1]
  if cmd == "decode":
    cmd_decode(work)
  elif cmd == "plan":
    scope = "versioned"
    if "--scope" in args:
      scope = args[args.index("--scope") + 1]
    if scope not in ("stale", "versioned"):
      sys.exit("--scope must be stale or versioned")
    cmd_plan(work, scope)
  elif cmd == "replan":
    cmd_replan(work)
  else:
    cmd_verify(work)


if __name__ == "__main__":
  main()

#!/usr/bin/env bash

set -euo pipefail

# Print "<path>\t<hash>" for every scalar leaf of a JSON/JSONC file, so two
# machines can be diffed without any value (secrets included) ever printing.
#
#   leaf-hashes.sh FILE [JQ_FILTER]
#
# FILE may start with "~/" (expanded here, so it can be quoted when sent over
# ssh or rex). JQ_FILTER narrows the input, e.g. '.mcpServers' (default '.').
# Trailing commas are stripped first, since some editors write lenient JSON.
#
#   ssh HOST bash -s -- '~/.claude.json' .mcpServers <leaf-hashes.sh
#   rex -S LABEL new probe --json --keep-open -- bash -c "$(cat leaf-hashes.sh)" leaf-hashes '~/.claude.json'

file="${1:?usage: leaf-hashes.sh FILE [JQ_FILTER]}"
filter="${2:-.}"
file="${file/#\~/$HOME}"

if [[ ! -f "$file" ]]; then
  echo "MISSING $file" >&2
  exit 0
fi

if command -v sha256sum >/dev/null; then
  hash() { sha256sum | cut -c1-12; }
else
  hash() { shasum -a 256 | cut -c1-12; }
fi

perl -0pe 's/,(\s*[}\]])/$1/g' "$file" |
  jq -r "$filter | paths(scalars) as \$p | [(\$p | map(tostring) | join(\".\")), (getpath(\$p) | tostring | @base64)] | @tsv" |
  while IFS=$'\t' read -r path value; do
    printf '%s\t%s\n' "$path" "$(printf '%s' "$value" | base64 -d | hash)"
  done

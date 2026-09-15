#!/usr/bin/env bash
# Fish shell history cleanup and deduplication script
# Usage: fish-history-cleanup.sh [--max-repetitions=N] [--dry-run] [input_file]
# Without arguments, operates on ~/.local/share/fish/fish_history

set -euo pipefail

# Default configuration
MAX_REPETITIONS=5
DRY_RUN=false
INPUT_FILE="${HOME}/.local/share/fish/fish_history"
OUTPUT_FILE="${INPUT_FILE}.cleaned"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --max-repetitions=*)
    MAX_REPETITIONS="${1#*=}"
    shift
    ;;
  --max-repetitions)
    MAX_REPETITIONS="$2"
    shift 2
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  -h | --help)
    echo "Usage: $0 [OPTIONS] [INPUT_FILE]"
    echo ""
    echo "Options:"
    echo "  --max-repetitions N  Keep only N recent executions of each command (default: $MAX_REPETITIONS)"
    echo "  --dry-run            Show what would be done without writing"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Without INPUT_FILE, operates on ~/.local/share/fish/fish_history"
    exit 0
    ;;
  -*)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  *)
    INPUT_FILE="$1"
    shift
    ;;
  esac
done

# Verify input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: Input file '$INPUT_FILE' not found" >&2
  exit 1
fi

echo "=== Fish History Cleanup ===" >&2
echo "Input file: $INPUT_FILE" >&2
echo "Max repetitions per command: $MAX_REPETITIONS" >&2
echo "" >&2

# Count original entries
ORIGINAL_LINES=$(grep -c "^- cmd:" "$INPUT_FILE" 2>/dev/null || echo 0)
ORIGINAL_FILE_LINES=$(wc -l <"$INPUT_FILE")
echo "Original entries: $ORIGINAL_LINES commands, $ORIGINAL_FILE_LINES total lines" >&2

# Run Python cleanup script
# Export MAX_REPETITIONS for Python to access via environment
export MAX_REPETITIONS

create_python_script() {
  cat <<'PYTHON_SCRIPT'
import sys
import os
from collections import OrderedDict
from typing import Dict, List

# Get max_repetitions from environment
max_repetitions = int(os.environ.get('MAX_REPETITIONS', '5'))

def parse_history(lines):
    """Parse fish history lines into structured entries."""
    entries = []
    current_entry = {}
    
    for line in lines:
        line = line.rstrip('\n')
        if line.startswith('- cmd:'):
            if current_entry and current_entry.get('cmd'):
                entries.append(current_entry)
            current_entry = {'cmd': line[7:].strip(), 'when': None, 'added_when': None, 'paths': []}
        elif line.startswith('  when:'):
            try:
                current_entry['when'] = int(line[7:].strip())
            except ValueError:
                pass
        elif line.startswith('  added_when:'):
            try:
                current_entry['added_when'] = int(line[13:].strip())
            except ValueError:
                pass
        elif line.startswith('  paths:'):
            current_entry['paths'] = []
        elif line.startswith('    - '):
            current_entry['paths'].append(line[6:].strip())
    
    if current_entry and current_entry.get('cmd'):
        entries.append(current_entry)
    
    return entries

def deduplicate_entries(entries, max_rep):
    """Deduplicate entries keeping only recent occurrences for each command.
    
    Strategy: Sort by timestamp descending, then keep only the N most recent
    occurrences of each command.
    """
    sorted_entries = sorted(
        entries, 
        key=lambda e: e['when'] or 0, 
        reverse=True
    )
    
    cmd_counts = OrderedDict()
    result = []
    
    for entry in sorted_entries:
        cmd = entry['cmd']
        if cmd not in cmd_counts:
            cmd_counts[cmd] = 0
        
        if cmd_counts[cmd] < max_rep:
            result.append(entry)
            cmd_counts[cmd] += 1
    
    result.sort(key=lambda e: e['when'] or 0)
    return result

def format_entry(entry):
    """Format an entry back to fish history format."""
    lines = [f"- cmd: {entry['cmd']}"]
    lines.append(f"  when: {entry['when']}")
    if entry.get('added_when'):
        lines.append(f"  added_when: {entry['added_when']}")
    if entry['paths']:
        lines.append("  paths:")
        for p in entry['paths']:
            lines.append(f"    - {p}")
    return '\n'.join(lines)

input_file = sys.argv[1]
with open(input_file, 'r') as f:
    lines = f.readlines()

entries = parse_history(lines)
deduped = deduplicate_entries(entries, max_repetitions)

for entry in deduped:
    print(format_entry(entry))
    print()

unique_cmds = len(set(e['cmd'] for e in deduped))
print(f"\n=== Cleanup Summary ===", file=sys.stderr)
print(f"Output entries: {len(deduped)} commands", file=sys.stderr)
print(f"Unique commands: {unique_cmds}", file=sys.stderr)
print(f"Removed: {len(entries) - len(deduped)} duplicate/repeated entries", file=sys.stderr)
PYTHON_SCRIPT
}

if $DRY_RUN; then
  create_python_script | python3 - "$INPUT_FILE"
  echo "" >&2
  echo "Dry run - no changes written" >&2
else
  create_python_script | python3 - "$INPUT_FILE" >"$OUTPUT_FILE"

  # Backup and replace
  cp "$INPUT_FILE" "${INPUT_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
  mv "$OUTPUT_FILE" "$INPUT_FILE"
  OUTPUT_LINES=$(grep -c "^- cmd:" "$INPUT_FILE" 2>/dev/null || echo 0)
  OUTPUT_FILE_LINES=$(wc -l <"$INPUT_FILE")
  backup_file="${INPUT_FILE}".backup.*
  echo "Backup saved to $(ls -t $backup_file | head -n 1)" >&2
  echo "Wrote: $OUTPUT_LINES commands, $OUTPUT_FILE_LINES total lines" >&2
fi

echo "Done." >&2

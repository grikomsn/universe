# Fish Shell History Cleanup Plan

## Overview

The fish shell history file (`~/.local/share/fish/fish_history`) contains **9,282 lines** representing **3,790 command entries** with **3,756 unique commands**.

**Key Finding**: There are no true duplicates (exact same command + timestamp). Commands are repeated with different timestamps - this is intentional history tracking, not duplication.

## File Format

```
- cmd: <command>
  when: <unix_timestamp>        # last execution time
  added_when: <unix_timestamp>  # when first added (optional)
  paths:                         # optional, multiple paths possible
    - /path/to/something
```

**Statistics:**
- Total lines: 9,282
- Command entries: 3,790
- Unique commands: 3,756
- Repetition count: 34 entries can be trimmed (commands appearing >5 times)

## Analysis Results

### No True Duplicates Found

All 3,790 entries have unique `(command, timestamp)` pairs. The 34 "extra" entries come from commands executed multiple times in different sessions.

### Commands Appearing Multiple Times

| Command | Appears | With max-repetitions=3 | Can be trimmed |
|---------|---------|------------------------|----------------|
| `l` | 7 times | Keep 3 | Remove 4 |
| `opencode auth login` | 6 times | Keep 3 | Remove 3 |
| `~` | 4 times | Keep 3 | Remove 1 |
| `pi` | 4 times | Keep 3 | Remove 1 |
| `cat package.json` | 3 times | Keep 3 | Remove 0 |
| `~/.local/share/opencode/` | 3 times | Keep 3 | Remove 0 |
| `~/.config/opencode/` | 3 times | Keep 3 | Remove 0 |

### Total Removable Entries by Threshold

| `--max-repetitions=N` | Entries Removed | Final Size |
|----------------------|-----------------|------------|
| 5 (default) | 3 | 3,787 commands |
| 4 | ~6 | 3,784 commands |
| 3 | 9 | 3,781 commands |
| 2 | ~15 | 3,775 commands |
| 1 | 34 | 3,756 commands |

## Cleanup Strategies

### Strategy A: Limit Repetitions (Recommended)

Keep only the N most recent executions of each command using the built-in deduplication.

```bash
# Keep only 3 most recent executions of each command
./scripts/fish-history-cleanup.sh --max-repetitions=3 --dry-run

# Apply the cleanup (creates backup)
./scripts/fish-history-cleanup.sh --max-repetitions=3
```

**Pros:** Preserves meaningful history while removing noise
**Cons:** Some history patterns are lost

### Strategy B: Time-Based Age Filtering

Remove entries older than a configurable threshold. Given timestamps span Nov 22, 2025 to Jul 23, 2026.

**Pros:** Predictable size reduction
**Cons:** Loss of historical context

### Strategy C: Pattern-Based Exclusion

Remove specific noisy patterns:
- Navigation entries (`~`, `..`, `./path/`, `/path/`)
- Help commands (`--help`, `-h`)
- Repeated auth logins
- Simple `l` / `ls` variants

**Pros:** Target specific noise
**Cons:** Requires tuning, may remove useful info

## Script Usage

```bash
# Show help
./scripts/fish-history-cleanup.sh --help

# Dry run (preview changes)
./scripts/fish-history-cleanup.sh --max-repetitions=3 --dry-run

# Apply cleanup (creates timestamped backup)
./scripts/fish-history-cleanup.sh --max-repetitions=3

# Clean specific file
./scripts/fish-history-cleanup.sh --max-repetitions=5 /path/to/history

# Use in fish shell
fish-history-cleanup --max-repetitions=3 --dry-run
```

## Recommended Default Settings

For most users, `--max-repetitions=3` provides a good balance:
- Keeps 3 recent executions of each command
- Removes ~9 redundant entries (0.24% of total)
- Maintains useful history patterns

## Alternative: Aggressive Deduplication

For a minimal history file, use `--max-repetitions=1`:
- Keeps only the most recent execution of each unique command
- Removes 34 entries (0.9% of total)
- Reduces file from 9,282 to ~7,200 lines

## Files Modified

- `scripts/fish-history-cleanup.sh` - Executable cleanup script
- `.config/fish/functions/fish-history-cleanup.fish` - Fish function wrapper
- `docs/fish-history-cleanup.md` - This documentation

## Safety Features

1. **Automatic backup**: Creates `.backup.YYYYMMDD_HHMMSS` before changes
2. **Dry-run mode**: Preview changes with `--dry-run`
3. **Preserves format**: Output matches original fish history format
4. **No git tracking**: fish_history is user-specific (not tracked in repo)

## Integration Options

### Auto-clean on fish startup
Add to `~/.config/fish/conf.d/fish_history_trim.fish`:

```fish
# Auto-trim history if over 5000 entries
set -l history_count (grep -c "^- cmd:" ~/.local/share/fish/fish_history 2>/dev/null || echo 0)
if test $history_count -gt 5000
    echo "Trimming fish history..."
    fish-history-cleanup --max-repetitions=3
end
```

### Cron job (weekly)
```bash
# Add to crontab: crontab -e
0 2 * * 0 /path/to/scripts/fish-history-cleanup.sh --max-repetitions=3
```

## Next Steps

1. Run with `--dry-run` to preview changes
2. Adjust `--max-repetitions` as needed
3. Apply with or without `--dry-run`
4. Set up regular cleanup automation
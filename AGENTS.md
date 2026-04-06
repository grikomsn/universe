# Agent Guidelines

Dotfiles repo managed with `lnk`. Structure: `scripts/`, `fixes/`, `.config/fish/`, `darwin.lnk/`, `linux.lnk/`.

## Quick Commands

```bash
# Apply dotfiles
lnk pull                      # Cross-platform
lnk pull -H darwin           # macOS only
lnk pull -H linux            # Linux only

# Install/update Homebrew packages (macOS)
brew bundle --global

# Cursor/VS Code
bash scripts/cursor.sh       # Setup config + extensions
bash scripts/cursor-sync.sh  # Exact extension match
bash scripts/cursor-bisect.sh # Check drift

# Validate syntax (run after changes)
git ls-files '*.sh' | xargs -n 1 bash -n
git ls-files '*.fish' | xargs -n 1 fish -n

# Format
git ls-files '*.sh' | xargs shfmt -w -i 2
git ls-files '*.fish' | xargs fish_indent -w

# Sort keybindings (after editing)
node scripts/sort-keybinds.js
```

## Repo Mechanics

- **Manifests**: `.lnk` (cross-platform), `.lnk.darwin`, `.lnk.linux` — list paths to symlink into `$HOME`
- Adding a dotfile: put it in correct directory, add path to matching manifest
- Paths are `$HOME`-relative; quote paths with spaces
- Prefer symlinks; use idempotent ops (`mkdir -p`, `ln -sf`)

## Style

**All files**:
- Single newline at EOF; no trailing whitespace
- Preserve existing behavior; minimal changes
- Never print secrets/tokens
- 2-space indentation

**Bash**:
```bash
#!/usr/bin/env bash
set -euo pipefail  # for non-interactive scripts

# Platform checks
[[ "$(uname -o)" == "Darwin" ]]  # macOS
[[ "$(uname -s)" == "Linux" ]]     # Linux

# Patterns
[[ ... ]]           # conditionals (not [ ])
"$var"              # quote all variables
command -v tool     # check command exists
```

**Fish**:
```fish
function name --description '...' --wraps=cmd; ...; end
set -l var            # local
set -gx var           # global exported
type -q tool          # check exists
test (uname -o) = Darwin  # macOS
```

**Node**:
- CommonJS; use `node:` builtins
- Keep scripts deterministic; concise output

**JSON/VS Code**:
- `keybindings.json`: must be sorted
- `settings.json`: JSONC (trailing commas OK)

## Safety

- Never run destructive scripts (`install.sh`, `sysprefs.sh`, `fonts.sh`) unless explicitly asked — they use sudo, change system settings, install software
- Local gitconfig has signing enabled; don't disable it

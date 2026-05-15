# Agent Guidelines

Repo structure: `scripts/`, `fixes/`, `.config/fish/`, `darwin.lnk/`, `linux.lnk/`

## Commands

```bash
lnk pull                      # apply dotfiles
lnk pull -H darwin           # macOS only
lnk pull -H linux            # Linux only
brew bundle --global         # update Homebrew packages
bash scripts/cursor.sh       # setup Cursor/VS Code
bash scripts/cursor-sync.sh  # sync extensions
bash scripts/cursor-bisect.sh # check drift
```

Validate + format after changes:

```bash
git ls-files '*.sh' | xargs -n 1 bash -n
git ls-files '*.sh' | xargs shfmt -w -i 2
git ls-files '*.fish' | xargs -n 1 fish -n
git ls-files '*.fish' | xargs fish_indent -w
node scripts/sort-keybinds.js  # after editing keybindings.json
```

## Repo Mechanics

- **Manifests**: `.lnk` (cross-platform), `.lnk.darwin`, `.lnk.linux` — list paths to symlink into `$HOME`
- Add dotfile: place in directory, add path to matching manifest
- Paths are `$HOME`-relative
- Prefer symlinks; use idempotent ops (`mkdir -p`, `ln -sf`)

## Style

- 2-space indent, single newline at EOF, no trailing whitespace
- Bash: `set -euo pipefail`, `[[ ... ]]`, `"$var"`
- Fish: `set -l` (local), `set -gx` (exported)
- `keybindings.json`: must be sorted; `settings.json`: JSONC

## Safety

- Never run `install.sh`, `sysprefs.sh`, `fonts.sh` (destructive, require sudo)
- Preserve gitconfig signing

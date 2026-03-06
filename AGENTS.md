# Agent Guidelines (Dotfiles + Scripts)

This repo is a personal dotfiles repository managed with `lnk`. Most changes are:

- Shell scripts in `scripts/` and `fixes/`
- Fish config in `.config/fish/`
- Platform-specific dotfiles in `darwin.lnk/` and `linux.lnk/`
- `lnk` manifests: `.lnk`, `.lnk.darwin`, `.lnk.linux`

## Repo Mechanics (lnk)

- `lnk` manifests list paths to be symlinked into `$HOME`.
  - Cross-platform: `.lnk`
  - macOS-only: `.lnk.darwin` (sources from `darwin.lnk/`)
  - Linux-only: `.lnk.linux` (sources from `linux.lnk/`)
- When adding a new dotfile, add the path to the right manifest and commit the file under the matching directory.
- Prefer symlinks over copying; assume files may already be symlinked in the target system.
- Paths in manifests are `$HOME`-relative (e.g. `Library/Application Support/...`); keep them portable and quote paths with spaces in scripts.

## Common Commands

### Apply/Update Dotfiles

- Pull/sync dotfiles (typical): `lnk pull`
- Pull host-specific dotfiles:
  - macOS: `lnk pull -H darwin`
  - Linux: `lnk pull -H linux`

### Homebrew (macOS)

- Install/update Brew bundle (dotfile is `darwin.lnk/.Brewfile`): `brew bundle --global`
- Keep in mind there is also a repo-root `Brewfile` used for publishing; keep it in sync with `darwin.lnk/.Brewfile` when editing.

### Cursor/VS Code Sync

- Setup/symlink config + install missing extensions: `bash scripts/cursor.sh`
- Enforce exact extension set (install missing + uninstall extras): `bash scripts/cursor-sync.sh`
- Show extension drift (no changes): `bash scripts/cursor-bisect.sh`

## Build/Lint/Test (There Is No Traditional Test Runner)

Treat "tests" here as syntax/format validation of dotfiles and scripts.

### Run A Single "Test" (One File)

- Bash syntax: `bash -n scripts/cursor.sh`
- Fish syntax: `fish -n .config/fish/conf.d/01-brew.fish`
- Node syntax: `node --check scripts/sort-keybinds.js`

### Validate Everything (Suggested)

- Bash syntax (tracked files):
  - `git ls-files '*.sh' | xargs -n 1 bash -n`
- Fish syntax (tracked files):
  - `git ls-files '*.fish' | xargs -n 1 fish -n`
- Format Bash (write in-place):
  - `git ls-files '*.sh' | xargs shfmt -w -i 2`
- Format Fish (write in-place):
  - `git ls-files '*.fish' | xargs fish_indent -w`

### Quick Smoke Check For A Change

- If you touched bash/fish: run the syntax checks above.
- If you touched Cursor keybindings: run `node scripts/sort-keybinds.js`.
- If you touched manifests: sanity-scan `.lnk`, `.lnk.darwin`, `.lnk.linux` for the new path.

### JSON/JSONC Checks

- Keybindings ordering: `node scripts/sort-keybinds.js`
- VS Code/Cursor `settings.json` is effectively JSONC (trailing commas may exist); avoid tools that insist on strict JSON.

### Optional Linters (If Installed)

- ShellCheck (bash): `shellcheck scripts/*.sh fixes/*.sh bootstrap.sh`

## Code Style Guidelines

### General

- Preserve existing behavior; these scripts are user-environment sensitive.
- Files end with a single newline; avoid trailing whitespace.
- Prefer small, composable scripts/functions over large monoliths.
- Do not introduce new secrets; never print tokens/credentials in logs or commit messages.

### Bash Scripts

- Shebang: `#!/usr/bin/env bash`
- Assume modern bash (4+) is available (scripts use features like `readarray`).
- Formatting: use `shfmt -i 2` (preferred output is 2-space indents).
- Conditionals: prefer `[[ ... ]]` in bash; use `[ ... ]` only when needed for POSIX sh.
- Quoting: always quote variables (`"$var"`) and paths; be extra careful with paths under `darwin.lnk/Library/Application Support/...`.
- Arrays: prefer bash arrays over stringly-typed lists when iterating.
- Prefer idempotent operations (`mkdir -p`, `ln -sf`, guarded edits) so re-running scripts is safe.
- Platform checks (consistent with repo):
  - macOS: `[[ "$(uname -o)" == "Darwin" ]]`
  - Linux: `[[ "$(uname -s)" == "Linux" ]]`
- Error handling:
  - For non-interactive scripts, consider `set -euo pipefail` (but avoid it in scripts that intentionally probe/ignore failures).
  - Print human-facing failures to stderr and exit non-zero.
- External command presence: use `command -v tool >/dev/null 2>&1`.

### Fish

- Functions:
  - Use `function name --description '...'; ...; end`.
  - Prefer kebab-case for function names (matches existing `brew-everything`, `git-save-me`, etc.).
- Variables:
  - Prefer `set -l` for locals; `set -gx` for exported globals.
- Command checks:
  - Prefer `type -q tool` generally.
  - Use `command -q tool` when you must avoid picking up functions/wrappers.
- Formatting:
  - Use `fish_indent -w` for consistent indentation.
- LSP directives:
  - Keep existing `# @fish-lsp-disable ...` where it is intentionally suppressing warnings.
- When wrapping builtins (e.g. `cat`), use `command ...` to avoid recursive calls.

### Node/JavaScript (Utility Scripts)

- This repo uses simple Node scripts (see `scripts/sort-keybinds.js`).
- Use Node-compatible CommonJS unless the surrounding code is already ESM.
- Prefer `node:` builtins (e.g. `require('node:fs')`).
- Imports: keep `require(...)` at the top; group builtins first.
- Formatting: 2-space indentation; keep changes minimal (no repo-wide reformat unless asked).
- Keep scripts deterministic and safe to run from repo root.
- Output should be concise; avoid dumping large file contents.

### JSON / VS Code Config

- `keybindings.json` should be sorted via `node scripts/sort-keybinds.js`.
- `settings.json` (Cursor/VS Code) is JSONC-like in practice; keep 2-space indentation and minimal diffs.

## Safety Notes

- Destructive/bootstrap scripts exist (e.g. `scripts/install.sh`, `scripts/sysprefs.sh`, `scripts/fonts.sh`). Do not run them unless explicitly asked; they may prompt for sudo, change system settings, install software, and download from the network.
- This repo currently contains an npm auth token in `.npmrc`; treat it as sensitive:
  - Do not paste it into issues/PRs/chat logs.
  - Avoid commands that would print it (e.g. `cat .npmrc` in output).

## Editor/Assistant Rules

- Cursor rules: none found in `.cursor/rules/` or `.cursorrules`.
- Copilot rules: none found in `.github/copilot-instructions.md`.

## Git Notes

- Local gitconfig enables commit signing; do not disable signing in-repo to "make commits work".
- Keep merges/renames small and mechanical; dotfiles are often symlinked into a live environment.

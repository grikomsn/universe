# Agent Guidelines for Dotfiles Repository

## Overview

This is a personal dotfiles repository managed with `lnk`. It contains configuration files for Fish shell, Bash scripts, and platform-specific dotfiles for macOS and Linux.

## Testing/Validation

- **Bash scripts**: Use `bash -n script.sh` to check syntax
- **Fish functions**: Use `fish -n function.fish` to validate syntax
- **Shell formatting**: Run `shfmt -w -i 2 script.sh` to format bash scripts
- **JSON sorting**: Run `node scripts/sort-keybinds.js` to sort keybindings specifically for keybindings.json files.

## Code Style

### Shell Scripts (Bash)

- Use `#!/usr/bin/env bash` shebang
- 2-space indentation (enforced by shfmt)
- Use double brackets `[[ ]]` for conditionals
- Quote variables: `"$variable"` not `$variable`
- Platform checks: `if [[ "$(uname -o)" == "Darwin" ]]; then`

### Fish Functions

- Use `function name --description 'desc'` format
- Prefer `type -q` over `command -q` for checking commands
- Use `set -l` for local variables, `set -g` for globals
- Keep functions simple and focused on single tasks

### General

- No trailing whitespace
- Files end with single newline
- JSON files: 2-space indentation, sorted keys where applicable
- Prefer symlinks over copying files

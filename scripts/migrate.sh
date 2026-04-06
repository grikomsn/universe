#!/usr/bin/env bash
#
# migrate.sh - Re-clone lnk repo after history rewrite and re-sync dotfiles
# Useful when git filter-repo or force push changed the remote tree

set -euo pipefail

REPO_URL="https://github.com/grikomsn/universe.git"
REPO_DIR="$HOME/.config/lnk"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

echo "Checking lnk repo at $REPO_DIR..."

if [[ ! -d "$REPO_DIR/.git" ]]; then
	echo "Error: lnk repo not found at $REPO_DIR" >&2
	exit 1
fi

cd "$REPO_DIR"

if ! git remote get-url origin >/dev/null 2>&1; then
	echo "Error: No origin remote configured" >&2
	exit 1
fi

local_head=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
remote_head=$(git ls-remote origin HEAD 2>/dev/null | awk '{print $1}' || echo "unknown")
mismatch=0

if [[ "$local_head" != "$remote_head" && "$remote_head" != "unknown" ]]; then
	echo "Detected git tree mismatch:"
	echo "  Local HEAD:  $local_head"
	echo "  Remote HEAD: $remote_head"
	mismatch=1
fi

echo "Re-cloning lnk repo..."

old_repo="${REPO_DIR}.old-$(date +%Y%m%d-%H%M%S)"
mv "$REPO_DIR" "$old_repo"
echo "Old repo moved to: $old_repo"

mkdir -p "$(dirname "$REPO_DIR")"
git clone --depth 1 "$REPO_URL" "$REPO_DIR"

echo "Backing up existing dotfiles to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

for manifest in ".lnk" ".lnk.darwin" ".lnk.linux"; do
	[[ -f "$REPO_DIR/$manifest" ]] || continue

	while IFS= read -r path; do
		[[ -z "$path" ]] && continue
		[[ "$path" =~ ^# ]] && continue

		target="$HOME/$path"

		if [[ -e "$target" && ! -L "$target" ]]; then
			backup_path="$BACKUP_DIR/$path"
			mkdir -p "$(dirname "$backup_path")"
			cp -R "$target" "$backup_path" 2>/dev/null || true
			echo "  Backed up: $path"
		fi
	done <"$REPO_DIR/$manifest"
done

echo "Running lnk pull..."
lnk init -r "$REPO_URL"
lnk pull

if [[ "$(uname -o)" == "Darwin" ]]; then
	lnk pull -H darwin
fi
if [[ "$(uname -s)" == "Linux" ]]; then
	lnk pull -H linux
fi

echo ""
echo "Migration complete!"
echo "  Old repo: $old_repo"
echo "  Backups:  $BACKUP_DIR"

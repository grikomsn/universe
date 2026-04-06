#!/usr/bin/env bash
#
# migrate.sh - Check for lnk repo tree mismatch and re-sync dotfiles
# Useful after git history has been rewritten (e.g., filter-repo)

set -euo pipefail

REPO_URL="https://github.com/grikomsn/universe.git"
REPO_DIR="$HOME/.config/lnk"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

error() {
	echo "[migrate] Error: $*" >&2
	exit 1
}

info() {
	echo "[migrate] $*"
}

check_remote_mismatch() {
	if [[ ! -d "$REPO_DIR/.git" ]]; then
		error "lnk repo not found at $REPO_DIR"
	fi

	cd "$REPO_DIR"

	if ! git remote get-url origin >/dev/null 2>&1; then
		error "No origin remote configured"
	fi

	local_remote=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
	remote_head=$(git ls-remote origin HEAD 2>/dev/null | awk '{print $1}' || echo "unknown")

	if [[ "$local_remote" != "$remote_head" && "$remote_head" != "unknown" ]]; then
		info "Detected git tree mismatch:"
		info "  Local HEAD:  $local_remote"
		info "  Remote HEAD: $remote_head"
		return 1
	fi

	return 0
}

check_symlink_health() {
	local issues=0

	info "Checking symlink health..."

	# Read all manifests and check if symlinks are valid
	local manifests=(".lnk" ".lnk.darwin" ".lnk.linux")

	for manifest in "${manifests[@]}"; do
		[[ -f "$REPO_DIR/$manifest" ]] || continue

		while IFS= read -r path; do
			[[ -z "$path" ]] && continue
			[[ "$path" =~ ^# ]] && continue

			local target="$HOME/$path"
			local source="$REPO_DIR/$path"

			# Skip if source doesn't exist (might be platform-specific)
			[[ -e "$source" ]] || continue

			if [[ -L "$target" ]]; then
				# It's a symlink, check if it points to the right place
				local current_link
				current_link=$(readlink "$target")
				if [[ "$current_link" != "$source" ]]; then
					info "  Wrong symlink: $target -> $current_link (expected: $source)"
					((issues++))
				elif [[ ! -e "$target" ]]; then
					info "  Broken symlink: $target -> $current_link"
					((issues++))
				fi
			elif [[ -e "$target" ]]; then
				# Regular file exists instead of symlink
				info "  Regular file (not symlink): $target"
				((issues++))
			else
				# Missing entirely
				info "  Missing: $target should link to $source"
				((issues++))
			fi
		done <"$REPO_DIR/$manifest"
	done

	return $issues
}

backup_existing_files() {
	info "Backing up existing dotfiles to $BACKUP_DIR..."
	mkdir -p "$BACKUP_DIR"

	local manifests=(".lnk" ".lnk.darwin" ".lnk.linux")

	for manifest in "${manifests[@]}"; do
		[[ -f "$REPO_DIR/$manifest" ]] || continue

		while IFS= read -r path; do
			[[ -z "$path" ]] && continue
			[[ "$path" =~ ^# ]] && continue

			local target="$HOME/$path"

			if [[ -e "$target" && ! -L "$target" ]]; then
				local backup_path="$BACKUP_DIR/$path"
				mkdir -p "$(dirname "$backup_path")"
				cp -R "$target" "$backup_path" 2>/dev/null || true
				info "  Backed up: $path"
			fi
		done <"$REPO_DIR/$manifest"
	done
}

reclone_and_sync() {
	info "Re-cloning lnk repo..."

	# Backup current repo if needed
	if [[ -d "$REPO_DIR" ]]; then
		local old_repo="${REPO_DIR}.old-$(date +%Y%m%d-%H%M%S)"
		mv "$REPO_DIR" "$old_repo"
		info "Old repo moved to: $old_repo"
	fi

	# Fresh clone
	mkdir -p "$(dirname "$REPO_DIR")"
	git clone --depth 1 "$REPO_URL" "$REPO_DIR"

	info "Running lnk pull..."
	lnk init -r "$REPO_URL"
	lnk pull

	if [[ "$(uname -o)" == "Darwin" ]]; then
		lnk pull -H darwin
	fi
	if [[ "$(uname -s)" == "Linux" ]]; then
		lnk pull -H linux
	fi

	info "Migration complete!"
	info "Your old repo is at: $old_repo (if you need to recover anything)"
	info "Backup of regular files (non-symlinks) is at: $BACKUP_DIR"
}

perform_sync() {
	info "Performing lnk sync..."

	cd "$REPO_DIR"

	# Try to fetch and see if we can fast-forward
	if git fetch origin 2>/dev/null; then
		local local_commit remote_commit
		local_commit=$(git rev-parse HEAD)
		remote_commit=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)

		if [[ "$local_commit" != "$remote_commit" ]]; then
			info "Attempting to reset to origin..."
			git reset --hard "$remote_commit" || {
				info "Reset failed. Re-cloning recommended."
				return 1
			}
		fi
	fi

	# Re-run lnk
	lnk pull
	if [[ "$(uname -o)" == "Darwin" ]]; then
		lnk pull -H darwin
	fi
	if [[ "$(uname -s)" == "Linux" ]]; then
		lnk pull -H linux
	fi

	info "Sync complete!"
}

main() {
	info "Checking lnk repo at $REPO_DIR..."

	local mismatch=0
	local symlink_issues=0

	# Check for git tree mismatch
	if ! check_remote_mismatch; then
		mismatch=1
	fi

	# Check symlink health
	if ! check_symlink_health; then
		symlink_issues=1
	fi

	# If no issues, exit early
	if [[ $mismatch -eq 0 && $symlink_issues -eq 0 ]]; then
		info "No issues detected. Everything looks good!"
		exit 0
	fi

	# Report issues and ask what to do
	echo ""
	echo "Issues detected:"
	[[ $mismatch -eq 1 ]] && echo "  - Git tree mismatch (history was likely rewritten)"
	[[ $symlink_issues -eq 1 ]] && echo "  - Symlink issues found"
	echo ""
	echo "Options:"
	echo "  1) Re-clone fresh (safest, backs up your current files)"
	echo "  2) Try to sync in-place (may fail if histories diverged)"
	echo "  3) Exit and fix manually"
	echo ""

	read -rp "Choose option [1-3]: " choice

	case "$choice" in
		1)
			echo ""
			read -rp "This will backup and re-clone. Continue? [y/N]: " confirm
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				backup_existing_files
				reclone_and_sync
			else
				info "Cancelled."
				exit 0
			fi
			;;
		2)
			echo ""
			read -rp "Attempt in-place sync? [y/N]: " confirm
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				perform_sync
			else
				info "Cancelled."
				exit 0
			fi
			;;
		3|*)
			info "Exiting. You can re-run this script anytime."
			exit 0
			;;
	esac
}

main "$@"

function fish-history-cleanup --description 'Clean up and deduplicate fish shell history'
    # Usage: fish-history-cleanup [--max-repetitions=N] [--dry-run] [file]
    # Argument parsing lives in the bash script; resolve it through the
    # lnk-managed fish config symlink so this works from any directory.
    set -l script (path resolve $__fish_config_dir)/../../scripts/fish-history-cleanup.sh
    bash $script $argv
end

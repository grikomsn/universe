function fish-history-cleanup --description 'Clean up and deduplicate fish shell history'
    # Usage: fish-history-cleanup [--max-repetitions=N] [--dry-run] [file]
    # Default: operates on ~/.local/share/fish/fish_history

    # Default configuration
    set -l max_reps 5
    set -l dry_run
    set -l history_file ~/.local/share/fish/fish_history

    # Parse arguments
    for arg in $argv
        if string match -q --max-repetitions=* $arg
            set max_reps (string split -m1 = $arg)[2]
        else if string match -q --max-repetitions $arg
            # Skip, next arg is the value
            continue
        else if string match -q --dry-run $arg
            set dry_run true
        else if string match -q -h $arg
            echo "Usage: fish-history-cleanup [OPTIONS] [INPUT_FILE]"
            echo ""
            echo "Options:"
            echo "  --max-repetitions N  Keep only N recent executions of each command (default: $max_reps)"
            echo "  --dry-run            Show what would be done without writing"
            echo "  -h, --help           Show this help message"
            return 0
        else if test -z $history_file -o $history_file = "~/.local/share/fish/fish_history"
            set history_file $arg
        end
    end

    # Build command
    set -l cmd scripts/fish-history-cleanup.sh --max-repetitions=$max_reps
    if set -q dry_run
        set cmd $cmd --dry-run
    end
    set cmd $cmd $history_file

    # Run the cleanup script
    bash $cmd
end

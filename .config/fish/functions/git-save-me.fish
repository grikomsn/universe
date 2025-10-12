function git-save-me --description 'custom function to list dangling commits'
    git log --graph --oneline --decorate $(git fsck --no-reflog | awk '/dangling commit/ {print $3}')
end

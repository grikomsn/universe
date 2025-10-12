function cleanup-empty-dirs --description 'remove all empty directories recursively'
    while find . -type d -empty -delete 2>/dev/null | read -l
    end
end

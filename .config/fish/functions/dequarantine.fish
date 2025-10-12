function dequarantine --description 'dequarantine files or directories'
    if test (uname -o) = Darwin
        for item in $argv
            if test -d $item # if it's a directory
                xattr -rd com.apple.quarantine $item
            else # if it's a file
                xattr -c $item
            end
        end
    else
        echo "Not supported on this platform"
        exit 1
    end
end

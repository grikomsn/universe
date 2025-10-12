function dedupe-open-with-entries --description 'dedupe open with entries'
    if (uname -o) = Darwin
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
    else
        echo "Not supported on this platform"
        exit 1
    end
end

function dedupe-open-with-entries --description 'dedupe open with entries'
    if test (uname -s) = Darwin
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user
    else
        echo "Not supported on this platform"
        return 1
    end
end

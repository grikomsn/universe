function reset-launchpad --description 'reset launchpad'
    if test (uname -o) = Darwin
        defaults write com.apple.dock ResetLaunchPad -bool true
        killall Dock
    else
        echo "Not supported on this platform"
        exit 1
    end
end

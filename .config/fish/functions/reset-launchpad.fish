function reset-launchpad --description 'reset launchpad'
    if test (uname -s) = Darwin
        defaults write com.apple.dock ResetLaunchPad -bool true
        killall Dock
    else
        echo "Not supported on this platform"
        return 1
    end
end

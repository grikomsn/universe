if test (uname -s) = Darwin
    if not set -q HOMEBREW_PREFIX
        if test (uname -m) = arm64
            set -gx HOMEBREW_PREFIX /opt/homebrew
        else
            set -gx HOMEBREW_PREFIX /usr/local
        end
    end
else if test -d /home/linuxbrew/.linuxbrew
    set -q HOMEBREW_PREFIX; or set -gx HOMEBREW_PREFIX /home/linuxbrew/.linuxbrew
end

if set -q HOMEBREW_PREFIX; and test -d $HOMEBREW_PREFIX
    fish_add_path $HOMEBREW_PREFIX/bin $HOMEBREW_PREFIX/sbin
    fish_add_path $HOMEBREW_PREFIX/opt/curl/bin
    fish_add_path $HOMEBREW_PREFIX/opt/dotnet/libexec

    # https://github.com/orgs/Homebrew/discussions/4412#discussioncomment-8651316
    if status is-login; and test -x $HOMEBREW_PREFIX/bin/brew
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
    end
end

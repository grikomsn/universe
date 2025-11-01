if test (uname -o) = Darwin
    if not set -q HOMEBREW_PREFIX
        if test (uname -m) = arm64
            set -gx HOMEBREW_PREFIX /opt/homebrew
        else
            set -gx HOMEBREW_PREFIX /usr/local
        end
    end

    # https://github.com/orgs/Homebrew/discussions/4412#discussioncomment-8651316
    if test -d $HOMEBREW_PREFIX
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"

        # bin extras
        set -gx PATH $HOMEBREW_PREFIX/opt/curl/bin $PATH
        set -gx PATH $HOMEBREW_PREFIX/opt/dotnet/libexec $PATH
    end
end

if string match -q Linux (uname -s)
    # noop
end

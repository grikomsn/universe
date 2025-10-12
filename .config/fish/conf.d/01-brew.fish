if test (uname -o) = Darwin
    if test (uname -m) = arm64
        set -gx HOMEBREW_PREFIX /opt/homebrew
    else
        set -gx HOMEBREW_PREFIX /usr/local
    end

    # https://github.com/orgs/Homebrew/discussions/4412#discussioncomment-8651316
    if test -d $HOMEBREW_PREFIX
        $HOMEBREW_PREFIX/bin/brew shellenv | source

        # bin extras
        set -gx PATH $HOMEBREW_PREFIX/opt/curl/bin $PATH
        set -gx PATH $HOMEBREW_PREFIX/opt/dotnet/libexec $PATH
    end
end

if string match -qi linux (uname -o)
    # noop
end

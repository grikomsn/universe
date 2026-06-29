if test (uname -o) = Darwin
    if not set -q HOMEBREW_PREFIX
        if test (uname -m) = arm64
            set -gx HOMEBREW_PREFIX /opt/homebrew
        else
            set -gx HOMEBREW_PREFIX /usr/local
        end
    end

    if test -d $HOMEBREW_PREFIX
        fish_add_path $HOMEBREW_PREFIX/bin
        fish_add_path $HOMEBREW_PREFIX/sbin
        fish_add_path $HOMEBREW_PREFIX/opt/curl/bin
        fish_add_path $HOMEBREW_PREFIX/opt/dotnet/libexec

        # https://github.com/orgs/Homebrew/discussions/4412#discussioncomment-8651316
        if status is-login
            eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
        end
    end
end

if string match -q Linux (uname -s)
    # noop
end

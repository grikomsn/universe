set -l ARCH_NAME (uname -m)
if test $ARCH_NAME = arm64
    set -gx HOMEBREW_PREFIX /opt/homebrew
else
    set -gx HOMEBREW_PREFIX /usr/local
end

# https://github.com/orgs/Homebrew/discussions/4412#discussioncomment-8651316
if test -d $HOMEBREW_PREFIX
    $HOMEBREW_PREFIX/bin/brew shellenv | source

    # bin extras
    set -gx PATH $HOMEBREW_PREFIX/opt/curl/bin $PATH
end

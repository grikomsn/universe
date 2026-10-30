# @fish-lsp-disable 2002

# Interactive only: `ssh host 'rm …'` and other non-interactive fish runs
# must not stop on the -i confirmation prompts below.
if not status is-interactive
    return
end

# https://superuser.com/a/1688630
# https://github.com/fish-shell/fish-shell/commit/320cb6857f2b8c44e2caf76553ae931a15e10e81
abbr -a -- - 'cd -'

alias cp='cp -i'
alias grep='grep --color'
alias h='history'
alias l='ls -lah'
alias la='ls -lAFh'
alias ll='ls -lh'
alias md='mkdir -p'
alias mv='mv -i'
alias rd='rmdir'
alias rm='rm -i'

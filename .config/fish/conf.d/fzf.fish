# fzf key bindings (ctrl-r, ctrl-t, alt-c) must load at startup; a file in
# completions/ is only autoloaded when completing `fzf` itself.
if status is-interactive; and type -q fzf
    fzf --fish | source
end

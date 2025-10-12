# bun
if test -d $HOME/.bun
    set -gx BUN_INSTALL $HOME/.bun
    fish_add_path $BUN_INSTALL/bin
end

# chatwise
if test -d /Applications/ChatWise.app
    set -gx CHATWISE_INSTALL /Applications/ChatWise.app/Contents/MacOS
    fish_add_path $CHATWISE_INSTALL
end

# deno
if test -d $HOME/.deno
    set -gx DENO_INSTALL $HOME/.deno
    fish_add_path $DENO_INSTALL/bin
end

# filen-cli
if test -d $HOME/.filen-cli
    set -gx FILEN_CLI_INSTALL $HOME/.filen-cli
    fish_add_path $FILEN_CLI_INSTALL/bin
end

# fnm
if type -q fnm
    fnm env --use-on-cd | source
else
    if test -d $HOME/.fnm
        set -gx FNM_PATH $HOME/.fnm
    else if test -n "$XDG_DATA_HOME"
        set -gx FNM_PATH $XDG_DATA_HOME/fnm
    else if test (uname -o) = Darwin
        set -gx FNM_PATH "$HOME/Library/Application Support/fnm"
    else
        set -gx FNM_PATH $HOME/.local/share/fnm
    end
    fish_add_path $FNM_PATH
    if type -q fnm
        fnm env --use-on-cd | source
    end
end

# fzf
if type -q fzf
    fzf --fish | source
end

# go
if test -d $HOME/.go
    set -gx GOPATH $HOME/.go
    fish_add_path $GOPATH/bin
end

# lmstudio
if test -d $HOME/.lmstudio
    set -gx LM_STUDIO_INSTALL $HOME/.lmstudio
    fish_add_path $LM_STUDIO_INSTALL/bin
end

# mkcert
if type -q mkcert
    set -gx NODE_EXTRA_CA_CERTS "$(mkcert -CAROOT)/rootCA.pem"
end

# opencode
if test -d $HOME/.opencode
    set -gx OPENCODE_INSTALL $HOME/.opencode
    fish_add_path $OPENCODE_INSTALL/bin
end

# orbstack
if test -f $HOME/.orbstack/shell/init2.fish
    source $HOME/.orbstack/shell/init2.fish 2>/dev/null || :
end

# pnpm
set -gx PNPM_HOME $HOME/Library/pnpm
fish_add_path $PNPM_HOME

# rust
if test -d $HOME/.cargo
    source "$HOME/.cargo/env.fish"
end

# yarn
set -gx YARN_INSTALL $HOME/.yarn
fish_add_path $YARN_INSTALL/bin

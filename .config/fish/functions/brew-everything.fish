function brew-everything --description 'upgrade bun deno fnm rustup brew etc.'
    if type -q bun
        bun upgrade
    end
    if type -q deno
        deno upgrade
    end
    if type -q fnm
        fnm install --lts
    end
    if type -q rustup
        rustup upgrade
    end
    if type -q brew
        brew update -vvv
        brew upgrade -vvv
        brew cleanup -vvv
        brew doctor -vvv
        brew autoremove -vvv
    end
end

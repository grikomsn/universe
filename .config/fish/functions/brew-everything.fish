function brew-everything --description 'upgrade bun deno fnm rustup brew mas dnf etc.'
    if type -q bun
        echo '==> bun'
        bun upgrade
    end
    if type -q deno
        echo '==> deno'
        deno upgrade
    end
    if type -q fnm
        echo '==> fnm'
        fnm install --lts
    end
    if type -q rustup
        echo '==> rustup'
        rustup upgrade
    end
    if type -q brew
        echo '==> brew'
        brew update
        brew upgrade
        brew cleanup
        brew autoremove
    end
    if type -q mas
        echo '==> mac app store'
        mas upgrade
    end
    if type -q dnf
        echo '==> dnf'
        sudo dnf upgrade -y
        sudo dnf autoremove -y
    end
    if type -q flatpak
        echo '==> flatpak'
        flatpak update --noninteractive
    end
end

function node-update-globals --description 'update node related package managers and global packages'
    # Remove stray package files in home that can interfere with global installs
    for f in ~/package.json ~/package-lock.json
        if test -f $f
            echo "removing stray $f"
            rm $f
        end
    end

    npm -g i npm@latest corepack@latest
    corepack enable pnpm
    corepack enable yarn
    corepack prepare --activate pnpm@latest
    corepack prepare --activate yarn@1.22.22

    # npm global packages (consolidated - moved from pnpm)
    set -l npm_pkgs @earendil-works/pi-coding-agent fish-lsp neovim prettier serve tsx turbo vercel

    # Update npm globals (skip npm update to avoid .DS_Store issues)
    if type -q npm
        npm -g install $npm_pkgs
    end

    # Ensure npm packages are not in pnpm
    if type -q pnpm
        set -l pnpm_dups
        for pkg in $npm_pkgs
            if pnpm --global list $pkg 2>/dev/null | grep -q $pkg
                set -a pnpm_dups $pkg
            end
        end
        if set -q pnpm_dups[1]
            echo "removing from pnpm (should be in npm only): $pnpm_dups"
            pnpm --global remove $pnpm_dups 2>/dev/null
        end
    end

    # Ensure npm packages are not in yarn
    if type -q yarn
        set -l yarn_dups
        for pkg in $npm_pkgs
            if yarn global list 2>/dev/null | grep -q $pkg
                set -a yarn_dups $pkg
            end
        end
        if set -q yarn_dups[1]
            echo "removing from yarn (should be in npm only): $yarn_dups"
            yarn global remove $yarn_dups 2>/dev/null
        end
        # yarn global upgrade
    end

    # Ensure npm packages are not in bun
    if type -q bun
        set -l bun_dups
        for pkg in $npm_pkgs
            if bun pm ls -g 2>/dev/null | grep -q $pkg
                set -a bun_dups $pkg
            end
        end
        if set -q bun_dups[1]
            echo "removing from bun (should be in npm only): $bun_dups"
            bun remove --global $bun_dups 2>/dev/null
        end
        # bun update --global
    end
end

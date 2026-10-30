function node-update-globals --description 'update node versions via fnm, set lts default, prune old versions, update global packages'
    # Remove stray package files in home that can interfere with global installs
    for f in ~/package.json ~/package-lock.json
        if test -f $f
            echo "removing stray $f"
            rm $f
        end
    end

    # fnm: install latest versions, default to latest LTS, prune old versions
    if type -q fnm
        fnm install --lts
        # fnm 1.x has no `latest` alias and `--latest` can hit prereleases; resolve latest stable.
        # Match whole tokens only, so v27.0.0-alpha.0.0.0 is not picked up as v27.0.0
        set -l latest_stable (fnm ls-remote | string match -r --all -- '^\S+' | string match -r --all -- '^v\d+\.\d+\.\d+$' | tail -1)
        if set -q latest_stable[1]
            fnm install $latest_stable
        end
        fnm default lts-latest
        fnm use lts-latest

        # Cleanup: for each major version, keep only the newest installed patch
        set -l all_versions (fnm ls | string match -r --all -- 'v\d+\.\d+\.\d+')
        set -l majors
        for v in $all_versions
            set -l major (string replace -r '^v(\d+)\..*' '$1' $v)
            if not contains $major $majors
                set -a majors $major
            end
        end
        for major in $majors
            set -l in_major
            for v in $all_versions
                if string match -q "v$major.*" $v
                    set -a in_major $v
                end
            end
            set -l keep (printf '%s\n' $in_major | string replace -r '^v' '' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
            for v in $in_major
                if test "$v" != "v$keep"
                    echo "removing old node $v (superseded by v$keep in major $major)"
                    fnm uninstall $v
                end
            end
        end
    end

    npm -g i npm@latest corepack@latest
    corepack enable pnpm
    corepack enable yarn
    corepack prepare --activate pnpm@latest
    corepack prepare --activate yarn@1.22.22

    # npm global packages (consolidated - moved from pnpm)
    set -l npm_pkgs fish-lsp neovim prettier serve tsx turbo vercel

    # Update npm globals (skip npm update to avoid .DS_Store issues)
    if type -q npm
        npm -g install $npm_pkgs $argv
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

    # bun global packages
    set -l bun_pkgs @earendil-works/pi-coding-agent

    # Update bun globals
    if type -q bun
        bun install --global $bun_pkgs $argv
    end

    # Ensure bun packages are not in npm
    if type -q npm
        set -l npm_dups
        for pkg in $bun_pkgs
            if npm -g list $pkg 2>/dev/null | grep -q $pkg
                set -a npm_dups $pkg
            end
        end
        if set -q npm_dups[1]
            echo "removing from npm (should be in bun only): $npm_dups"
            npm -g remove $npm_dups 2>/dev/null
        end
    end
end

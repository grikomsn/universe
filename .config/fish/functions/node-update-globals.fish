function node-update-globals --description 'update node related package managers and global packages'
    npm -g i npm@latest corepack@latest
    corepack enable pnpm
    corepack enable yarn
    corepack prepare --activate pnpm@latest
    corepack prepare --activate yarn@1.22.22

    set -l all_packages

    # Node.js helper to extract package names from npm/pnpm JSON output
    # Handles both npm's single object and pnpm's array format
    set -l extract_script 'const fs=require("node:fs");const input=fs.readFileSync(0,"utf8").trim();if(!input)process.exit(0);const data=JSON.parse(input);const packages=new Set();for(const entry of(Array.isArray(data)?data:[data])){const deps=entry?.dependencies||{};for(const name of Object.keys(deps)){if(!["npm","pnpm","corepack","yarn"].includes(name))packages.add(name);}}process.stdout.write([...packages].join("\n"));'

    # Detect npm globals
    if type -q npm
        set -l npm_packages (npm ls -g --depth=0 --json 2>/dev/null | node -e $extract_script | string split '\n')
        set -a all_packages $npm_packages
    end

    # Detect pnpm globals
    if type -q pnpm
        set -l pnpm_packages (pnpm --global list --depth 0 --json 2>/dev/null | node -e $extract_script | string split '\n')
        set -a all_packages $pnpm_packages
    end

    # Detect bun globals
    # bun pm ls -g outputs: /path/to/global\n├── name@version\n└── name@version
    if type -q bun
        set -l bun_packages (bun pm ls -g 2>/dev/null | string replace -r '^[├└]──\s+([^@]+)@.*' '$1' | string match -v '^/')
        set -a all_packages $bun_packages
    end

    # Deduplicate and remove empty entries
    set -l unique_packages (printf "%s\n" $all_packages | sort -u | string trim | string match -v '^$')

    if set -q unique_packages[1]
        pnpm --global add $unique_packages
    end
end

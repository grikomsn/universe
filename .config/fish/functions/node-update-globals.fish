function node-update-globals --description 'update node related package managers and global packages'
    npm -g i npm@latest corepack@latest
    corepack enable pnpm
    corepack enable yarn
    corepack prepare --activate pnpm@latest
    corepack prepare --activate yarn@1.22.22

    set -l NODE_GLOBAL_PACKAGES (
        pnpm --global list --depth 0 --json | node -e '
const fs = require("node:fs")
const input = fs.readFileSync(0, "utf8").trim()

if (!input) {
  process.exit(0)
}

const installed = JSON.parse(input)
const packages = new Set()

for (const entry of installed) {
  const dependencies = entry && entry.dependencies ? entry.dependencies : {}

  for (const name of Object.keys(dependencies)) {
    if (name !== "npm" && name !== "pnpm" && name !== "corepack" && name !== "yarn") {
      packages.add(name)
    }
  }
}

process.stdout.write([...packages].join("\n"))
'
    )

    if set -q NODE_GLOBAL_PACKAGES[1]
        pnpm --global add $NODE_GLOBAL_PACKAGES
    end
end

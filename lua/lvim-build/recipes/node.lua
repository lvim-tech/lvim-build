-- lvim-build.recipes.node: a JS/TS project — ONE action per package.json `scripts` entry, run
-- with the package manager the lockfile identifies (bun/pnpm/yarn, npm otherwise). The script
-- NAME drives the group heuristic (test/lint/dev/build…).
--
---@module "lvim-build.recipes.node"

local context = require("lvim-build.context")
local util = require("lvim-build.recipes.util")

-- lockfile → package manager, checked in this order next to package.json
local LOCKS = {
    { "bun.lockb", "bun" },
    { "bun.lock", "bun" },
    { "pnpm-lock.yaml", "pnpm" },
    { "yarn.lock", "yarn" },
}

---@type LvimBuildRecipe
return {
    name = "node",
    kind = "project",
    markers = { "package.json" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "package.json")
        local lines = marker and context.readlines(marker) or nil
        if not lines then
            return {}
        end
        local ok, pkg = pcall(vim.json.decode, table.concat(lines, "\n"))
        if not ok or type(pkg) ~= "table" or type(pkg.scripts) ~= "table" then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local pm = "npm"
        for _, l in ipairs(LOCKS) do
            if vim.fn.filereadable(cwd .. "/" .. l[1]) == 1 then
                pm = l[2]
                break
            end
        end
        -- stable order: scripts sorted by name (pairs() order would shuffle the chooser)
        local names = {}
        for name in pairs(pkg.scripts) do
            names[#names + 1] = name
        end
        table.sort(names)
        local out = {}
        for _, name in ipairs(names) do
            out[#out + 1] = {
                name = pm .. " run " .. name,
                group = util.group_of(name),
                cmd = { pm, "run", name },
                cwd = cwd,
                matcher = "generic",
            }
        end
        return out
    end,
}

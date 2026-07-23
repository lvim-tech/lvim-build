-- lvim-build.recipes.crystal: a crystal project. Resolves `crystal` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.crystal"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("crystal", "crystal", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("crystal")
    return p ~= "" and p or "crystal"
end

---@type LvimBuildRecipe
return {
    name = "crystal",
    kind = "project",
    markers = { "shard.yml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "shard.yml" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("crystal build", "Build", { bin, "build" }),
            act("crystal run", "Run", { bin, "run" }),
            act("crystal spec", "Test", { bin, "spec" }),
        }
    end,
}

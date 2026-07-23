-- lvim-build.recipes.v: a v project. Resolves `v` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.v"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("v", "v", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("v")
    return p ~= "" and p or "v"
end

---@type LvimBuildRecipe
return {
    name = "v",
    kind = "project",
    markers = { "v.mod" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "v.mod" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("v build", "Build", { bin, "." }),
            act("v run", "Run", { bin, "run", "." }),
            act("v test", "Test", { bin, "test", "." }),
        }
    end,
}

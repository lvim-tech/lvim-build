-- lvim-build.recipes.cairo: a Cairo/Scarb project. Resolves `scarb` through lvim-lang.core.toolchain when
-- its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.cairo"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("cairo", "scarb", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("scarb")
    return p ~= "" and p or "scarb"
end

---@type LvimBuildRecipe
return {
    name = "cairo",
    kind = "project",
    markers = { "Scarb.toml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "Scarb.toml" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local b = bin(cwd)
        local function act(name, group, argv)
            argv[1] = b
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("scarb build", "Build", { "scarb", "build" }),
            act("scarb test", "Test", { "scarb", "test" }),
        }
    end,
}

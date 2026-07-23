-- lvim-build.recipes.purescript: a purescript project. Resolves `spago` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.purescript"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("purescript", "spago", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("spago")
    return p ~= "" and p or "spago"
end

---@type LvimBuildRecipe
return {
    name = "purescript",
    kind = "project",
    markers = { "spago.yaml", "spago.dhall" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "spago.yaml", "spago.dhall" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("spago build", "Build", { bin, "build" }),
            act("spago test", "Test", { bin, "test" }),
        }
    end,
}

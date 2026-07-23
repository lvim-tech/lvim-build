-- lvim-build.recipes.fish: a fish-script project. Resolves `fish` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.fish"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("fish", "fish", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("fish")
    return p ~= "" and p or "fish"
end

---@type LvimBuildRecipe
return {
    name = "fish",
    kind = "project",
    markers = { "config.fish" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "config.fish" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("fish -n (syntax check)", "Build", { bin, "-n", "config.fish" }),
        }
    end,
}

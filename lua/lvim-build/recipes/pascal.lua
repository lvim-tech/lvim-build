-- lvim-build.recipes.pascal: a Lazarus/Pascal project. Resolves `lazbuild` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.pascal"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("pascal", "lazbuild", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("lazbuild")
    return p ~= "" and p or "lazbuild"
end

---@type LvimBuildRecipe
return {
    name = "pascal",
    kind = "project",
    markers = { "*.lpi" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "*.lpi" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("lazbuild", "Build", { bin, "." }),
        }
    end,
}

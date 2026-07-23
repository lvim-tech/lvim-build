-- lvim-build.recipes.roc: a Roc project. Resolves `roc` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.roc"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("roc", "roc", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("roc")
    return p ~= "" and p or "roc"
end

---@type LvimBuildRecipe
return {
    name = "roc",
    kind = "project",
    markers = { "main.roc" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "main.roc" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("roc build", "Build", { bin, "build" }),
            act("roc dev", "Run", { bin, "dev" }),
            act("roc test", "Test", { bin, "test" }),
        }
    end,
}

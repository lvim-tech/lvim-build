-- lvim-build.recipes.odin: a odin project. Resolves `odin` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.odin"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("odin", "odin", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("odin")
    return p ~= "" and p or "odin"
end

---@type LvimBuildRecipe
return {
    name = "odin",
    kind = "project",
    markers = { "ols.json" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "ols.json" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("odin build", "Build", { bin, "build", "." }),
            act("odin run", "Run", { bin, "run", "." }),
            act("odin test", "Test", { bin, "test", "." }),
        }
    end,
}

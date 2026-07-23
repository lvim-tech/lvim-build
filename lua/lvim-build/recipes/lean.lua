-- lvim-build.recipes.lean: a Lean 4 (Lake) project. Resolves `lake` through lvim-lang.core.toolchain when
-- its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.lean"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("lean", "lake", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("lake")
    return p ~= "" and p or "lake"
end

---@type LvimBuildRecipe
return {
    name = "lean",
    kind = "project",
    markers = { "lakefile.lean", "lakefile.toml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "lakefile.lean", "lakefile.toml" })
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
            act("lake build", "Build", { "lake", "build" }),
            act("lake test", "Test", { "lake", "test" }),
        }
    end,
}

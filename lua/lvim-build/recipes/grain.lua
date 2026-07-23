-- lvim-build.recipes.grain: a Grain project. Resolves `grain` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.grain"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("grain", "grain", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("grain")
    return p ~= "" and p or "grain"
end

---@type LvimBuildRecipe
return {
    name = "grain",
    kind = "project",
    markers = { "package.json" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "package.json" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("grain compile", "Build", { bin, "compile", "main.gr" }),
            act("grain run", "Run", { bin, "run", "main.gr" }),
        }
    end,
}

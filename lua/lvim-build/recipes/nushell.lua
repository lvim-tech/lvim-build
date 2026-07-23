-- lvim-build.recipes.nushell: a Nushell-script project. Resolves `nu` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.nushell"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("nushell", "nu", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("nu")
    return p ~= "" and p or "nu"
end

---@type LvimBuildRecipe
return {
    name = "nushell",
    kind = "project",
    markers = { "config.nu" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "config.nu" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("nu config.nu", "Run", { bin, "config.nu" }),
        }
    end,
}

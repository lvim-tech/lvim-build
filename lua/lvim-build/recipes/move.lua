-- lvim-build.recipes.move: a Move project (Aptos / Sui). Resolves `move` through lvim-lang.core.toolchain when
-- its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.move"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("move", "move", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("move")
    return p ~= "" and p or "move"
end

---@type LvimBuildRecipe
return {
    name = "move",
    kind = "project",
    markers = { "Move.toml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "Move.toml" })
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
            act("move build", "Build", { "move", "build" }),
            act("move test", "Test", { "move", "test" }),
        }
    end,
}

-- lvim-build.recipes.gleam: a gleam project. Resolves `gleam` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.gleam"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("gleam", "gleam", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("gleam")
    return p ~= "" and p or "gleam"
end

---@type LvimBuildRecipe
return {
    name = "gleam",
    kind = "project",
    markers = { "gleam.toml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "gleam.toml" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("gleam build", "Build", { bin, "build" }),
            act("gleam run", "Run", { bin, "run" }),
            act("gleam test", "Test", { bin, "test" }),
        }
    end,
}

-- lvim-build.recipes.ada: a ada project. Resolves `gprbuild` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.ada"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("ada", "gprbuild", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("gprbuild")
    return p ~= "" and p or "gprbuild"
end

---@type LvimBuildRecipe
return {
    name = "ada",
    kind = "project",
    markers = { "alire.toml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "alire.toml" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("gprbuild", "Build", { bin }),
            act("alr build", "Build", { "alr", "build" }),
            act("alr test", "Test", { "alr", "test" }),
        }
    end,
}

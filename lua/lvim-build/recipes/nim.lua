-- lvim-build.recipes.nim: a nim project. Resolves `nim` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.nim"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("nim", "nim", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("nim")
    return p ~= "" and p or "nim"
end

---@type LvimBuildRecipe
return {
    name = "nim",
    kind = "project",
    markers = { "config.nims", "nim.cfg" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "config.nims", "nim.cfg" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("nim c", "Build", { bin, "c", "." }),
            act("nimble build", "Build", { "nimble", "build" }),
            act("nimble test", "Test", { "nimble", "test" }),
        }
    end,
}

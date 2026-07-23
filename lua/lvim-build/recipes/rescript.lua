-- lvim-build.recipes.rescript: a ReScript project. Resolves `rescript` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.rescript"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("rescript", "rescript", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("rescript")
    return p ~= "" and p or "rescript"
end

---@type LvimBuildRecipe
return {
    name = "rescript",
    kind = "project",
    markers = { "rescript.json", "bsconfig.json" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "rescript.json", "bsconfig.json" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("rescript build", "Build", { bin, "build" }),
            act("rescript build -w", "Run", { bin, "build", "-w" }),
            act("rescript clean", "Build", { bin, "clean" }),
        }
    end,
}

-- lvim-build.recipes.vala: a Vala/meson project. Resolves `meson` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.vala"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("vala", "meson", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("meson")
    return p ~= "" and p or "meson"
end

---@type LvimBuildRecipe
return {
    name = "vala",
    kind = "project",
    markers = { "meson.build" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "meson.build" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("meson setup build", "Build", { bin, "setup", "build", "--reconfigure" }),
            act("meson compile", "Build", { bin, "compile", "-C", "build" }),
            act("meson test", "Test", { bin, "test", "-C", "build" }),
        }
    end,
}

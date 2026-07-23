-- lvim-build.recipes.julia: a Julia project (Project.toml / JuliaProject.toml upward of the file/cwd) —
-- instantiate deps and run the package test suite through `Pkg`. When lvim-lang is installed and its
-- Julia provider is active, `julia` is resolved through `lvim-lang.core.toolchain` first, then PATH;
-- lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.julia"

local context = require("lvim-build.context")

--- Resolve the `julia` binary: the lvim-lang Julia toolchain when active for `root`, else PATH.
---@param root string
---@return string
local function julia_bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("julia", "julia", root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    local p = vim.fn.exepath("julia")
    return p ~= "" and p or "julia"
end

---@type LvimBuildRecipe
return {
    name = "julia",
    kind = "project",
    markers = { "Project.toml", "JuliaProject.toml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "Project.toml", "JuliaProject.toml" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local julia = julia_bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("Pkg.instantiate", "Build", { julia, "--project=.", "-e", "using Pkg; Pkg.instantiate()" }),
            act("Pkg.test", "Test", { julia, "--project=.", "-e", "using Pkg; Pkg.test()" }),
        }
    end,
}

-- lvim-build.recipes.d: a D project (dub.json / dub.sdl upward of the file/cwd) — the standard `dub`
-- verbs (build / run / test). When lvim-lang is installed and its D provider is active, `dub` is
-- resolved through `lvim-lang.core.toolchain` first (honouring an explicit path), then PATH; lvim-build
-- works fully without lvim-lang.
--
---@module "lvim-build.recipes.d"

local context = require("lvim-build.context")

--- Resolve the `dub` binary: the lvim-lang D toolchain when active for `root`, else PATH, else the name.
---@param root string
---@return string
local function dub_bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("d", "dub", root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    local p = vim.fn.exepath("dub")
    return p ~= "" and p or "dub"
end

---@type LvimBuildRecipe
return {
    name = "d",
    kind = "project",
    markers = { "dub.json", "dub.sdl" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "dub.json", "dub.sdl" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local dub = dub_bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("dub build", "Build", { dub, "build" }),
            act("dub run", "Run", { dub, "run" }),
            act("dub test", "Test", { dub, "test" }),
        }
    end,
}

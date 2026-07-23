-- lvim-build.recipes.zig: a Zig project (build.zig upward of the file/cwd) — the standard `zig`
-- verbs, parsed with the gcc problem matcher (Zig emits the exact `file:line:col: error: msg`
-- shape). `zig` is one self-contained binary — compiler, build system, test runner AND formatter
-- (`zig fmt`) — so every action is a `zig` subcommand. When lvim-lang is installed and its Zig
-- provider is active, the `zig` binary is resolved through `lvim-lang.core.toolchain` first
-- (honouring an explicit path / mise / asdf), then PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.zig"

local context = require("lvim-build.context")

--- Resolve the `zig` binary: the lvim-lang Zig toolchain when active for `root`, else the bare name
--- (found on PATH at run time by lvim-tasks).
---@param root string
---@return string
local function zig_bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("zig", "zig", root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return "zig"
end

---@type LvimBuildRecipe
return {
    name = "zig",
    kind = "project",
    markers = { "build.zig" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "build.zig")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local zig = zig_bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = "gcc" }
        end
        return {
            act("zig build", "Build", { zig, "build" }),
            act("zig build run", "Run", { zig, "build", "run" }),
            act("zig build test", "Test", { zig, "build", "test" }),
            act("zig fmt", "Lint", { zig, "fmt", "." }),
        }
    end,
}

-- lvim-build.recipes.perl: a Perl distribution (Makefile.PL / Build.PL / dist.ini / cpanfile upward of
-- the file/cwd) — `prove -lr t` for the test suite, plus the build step for the detected layout
-- (ExtUtils::MakeMaker's `perl Makefile.PL`, or Dist::Zilla's `dzil build`). When lvim-lang is installed
-- and its Perl provider is active, `perl` is resolved through `lvim-lang.core.toolchain` first, then
-- PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.perl"

local context = require("lvim-build.context")

--- Resolve the `perl` binary: the lvim-lang Perl toolchain when active for `root`, else PATH.
---@param root string
---@return string
local function perl_bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("perl", "perl", root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    local p = vim.fn.exepath("perl")
    return p ~= "" and p or "perl"
end

---@type LvimBuildRecipe
return {
    name = "perl",
    kind = "project",
    markers = { "Makefile.PL", "Build.PL", "dist.ini", "cpanfile" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local mk = context.marker(ctx, "Makefile.PL")
        local dz = context.marker(ctx, "dist.ini")
        local marker = mk or dz or context.marker(ctx, { "Build.PL", "cpanfile" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local perl = perl_bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        -- prove drives the test suite for every layout; the build step depends on the tooling.
        local actions = { act("prove -lr t", "Test", { "prove", "-lr", "t" }) }
        if mk then
            actions[#actions + 1] = act("perl Makefile.PL", "Build", { perl, "Makefile.PL" })
        elseif dz then
            actions[#actions + 1] = act("dzil build", "Build", { "dzil", "build" })
            actions[#actions + 1] = act("dzil test", "Test", { "dzil", "test" })
        end
        return actions
    end,
}

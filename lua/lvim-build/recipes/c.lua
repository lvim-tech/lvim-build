-- lvim-build.recipes.c: single-file C fallback — no Makefile/CMake/meson owns the buffer, so
-- compile it with gcc into the lvim-build cache dir, and offer compile-and-run. String commands
-- (the `&&` chain) with shell-quoted paths.
--
---@module "lvim-build.recipes.c"

local context = require("lvim-build.context")
local util = require("lvim-build.recipes.util")

---@type LvimBuildRecipe
return {
    name = "c",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if ctx.ft ~= "c" or ctx.file == "" then
            return {}
        end
        -- a project recipe owns this file → the fallback stays out of the chooser
        if context.marker(ctx, { "Makefile", "makefile", "GNUmakefile", "CMakeLists.txt", "meson.build" }) then
            return {}
        end
        local out = context.cache_dir() .. "/" .. vim.fn.fnamemodify(ctx.file, ":t:r")
        local compile = ("gcc %s -o %s"):format(util.q(ctx.file), util.q(out))
        local cwd = vim.fs.dirname(ctx.file)
        return {
            { name = "gcc build", group = "Build", cmd = compile, cwd = cwd, matcher = "gcc" },
            {
                name = "gcc build & run",
                group = "Run",
                cmd = compile .. " && " .. util.q(out),
                cwd = cwd,
                matcher = "gcc",
            },
        }
    end,
}

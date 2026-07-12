-- lvim-build.recipes.cpp: single-file C++ fallback — the c.lua twin with g++ (same cache-dir
-- output, same project-marker gate).
--
---@module "lvim-build.recipes.cpp"

local context = require("lvim-build.context")
local util = require("lvim-build.recipes.util")

---@type LvimBuildRecipe
return {
    name = "cpp",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if ctx.ft ~= "cpp" or ctx.file == "" then
            return {}
        end
        if context.marker(ctx, { "Makefile", "makefile", "GNUmakefile", "CMakeLists.txt", "meson.build" }) then
            return {}
        end
        local out = context.cache_dir() .. "/" .. vim.fn.fnamemodify(ctx.file, ":t:r")
        local compile = ("g++ %s -o %s"):format(util.q(ctx.file), util.q(out))
        local cwd = vim.fs.dirname(ctx.file)
        return {
            { name = "g++ build", group = "Build", cmd = compile, cwd = cwd, matcher = "gcc" },
            {
                name = "g++ build & run",
                group = "Run",
                cmd = compile .. " && " .. util.q(out),
                cwd = cwd,
                matcher = "gcc",
            },
        }
    end,
}

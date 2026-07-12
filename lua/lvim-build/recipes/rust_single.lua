-- lvim-build.recipes.rust_single: single-file Rust fallback — a .rs buffer OUTSIDE any cargo
-- project (Cargo.toml upward wins, cargo.lua handles it) compiles with rustc into the cache dir.
--
---@module "lvim-build.recipes.rust_single"

local context = require("lvim-build.context")
local util = require("lvim-build.recipes.util")

---@type LvimBuildRecipe
return {
    name = "rust_single",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if ctx.ft ~= "rust" or ctx.file == "" then
            return {}
        end
        if context.marker(ctx, "Cargo.toml") then
            return {}
        end
        local out = context.cache_dir() .. "/" .. vim.fn.fnamemodify(ctx.file, ":t:r")
        local compile = ("rustc %s -o %s"):format(util.q(ctx.file), util.q(out))
        local cwd = vim.fs.dirname(ctx.file)
        return {
            { name = "rustc build", group = "Build", cmd = compile, cwd = cwd, matcher = "rust" },
            {
                name = "rustc build & run",
                group = "Run",
                cmd = compile .. " && " .. util.q(out),
                cwd = cwd,
                matcher = "rust",
            },
        }
    end,
}

-- lvim-build.recipes.lua: run the current Lua buffer with `nvim -l` — always available (it IS
-- the editor's runtime, LuaJIT + the vim.* stdlib), where a system `lua` may be absent. Offered
-- even inside a project: "run THIS lua file" is well-defined regardless of markers.
--
---@module "lvim-build.recipes.lua"

---@type LvimBuildRecipe
return {
    name = "lua",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if ctx.ft ~= "lua" or ctx.file == "" then
            return {}
        end
        return {
            {
                name = "nvim -l " .. vim.fn.fnamemodify(ctx.file, ":t"),
                group = "Run",
                cmd = { "nvim", "-l", ctx.file },
                cwd = vim.fs.dirname(ctx.file),
                matcher = "lua",
            },
        }
    end,
}

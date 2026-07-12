-- lvim-build.recipes.python_single: single-file Python fallback — run the current buffer with
-- `python3` when no pyproject.toml owns it (the project half lives in recipes/python.lua).
--
---@module "lvim-build.recipes.python_single"

local context = require("lvim-build.context")

---@type LvimBuildRecipe
return {
    name = "python_single",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if ctx.ft ~= "python" or ctx.file == "" then
            return {}
        end
        if context.marker(ctx, "pyproject.toml") then
            return {}
        end
        return {
            {
                name = "python " .. vim.fn.fnamemodify(ctx.file, ":t"),
                group = "Run",
                cmd = { "python3", ctx.file },
                cwd = vim.fs.dirname(ctx.file),
                matcher = "python",
            },
        }
    end,
}

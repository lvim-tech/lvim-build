-- lvim-build.recipes.python: Python — the PROJECT half reads pyproject.toml and offers pytest /
-- ruff only when the file mentions them (a text scan, not a TOML parse — "configured" is a
-- dependency or a [tool.…] table, both of which contain the word); the SINGLE-FILE half (via
-- recipes/… kind="file" gating in detect.lua) runs the current buffer when no pyproject owns it.
--
---@module "lvim-build.recipes.python"

local context = require("lvim-build.context")

---@type LvimBuildRecipe
return {
    name = "python",
    kind = "project",
    markers = { "pyproject.toml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "pyproject.toml")
        local lines = marker and context.readlines(marker) or nil
        if not lines then
            return {}
        end
        local text = table.concat(lines, "\n")
        local cwd = vim.fs.dirname(marker)
        local out = {}
        if text:find("pytest", 1, true) then
            out[#out + 1] = { name = "pytest", group = "Test", cmd = { "pytest" }, cwd = cwd, matcher = "python" }
        end
        if text:find("ruff", 1, true) then
            out[#out + 1] =
                { name = "ruff check", group = "Lint", cmd = { "ruff", "check", "." }, cwd = cwd, matcher = "generic" }
        end
        return out
    end,
}

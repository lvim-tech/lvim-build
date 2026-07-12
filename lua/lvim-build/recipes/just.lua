-- lvim-build.recipes.just: a justfile project — one action per RECIPE, from a tolerant line
-- scan: a recipe is `name … :` at column 0 (parameters allowed before the colon), skipping
-- comments, assignments (`:=`) and private `_`-prefixed recipes (the just convention).
--
---@module "lvim-build.recipes.just"

local context = require("lvim-build.context")
local util = require("lvim-build.recipes.util")

---@type LvimBuildRecipe
return {
    name = "just",
    kind = "project",
    markers = { "justfile", "Justfile", ".justfile" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "justfile", "Justfile", ".justfile" })
        local lines = marker and context.readlines(marker) or nil
        if not lines then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local seen, out = {}, {}
        for _, line in ipairs(lines) do
            if not line:find(":=", 1, true) then
                local recipe = line:match("^([%w][%w%-_]*)[^:#]*:")
                if recipe and not seen[recipe] then
                    seen[recipe] = true
                    out[#out + 1] = {
                        name = "just " .. recipe,
                        group = util.group_of(recipe),
                        cmd = { "just", recipe },
                        cwd = cwd,
                        matcher = "generic",
                    }
                end
            end
        end
        return out
    end,
}

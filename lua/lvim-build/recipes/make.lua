-- lvim-build.recipes.make: a Makefile project — one action per TARGET, from a tolerant line
-- scan (never a make parse): a target is `name:` at column 0, skipping dot-targets (.PHONY),
-- pattern rules (%), computed names ($…) and variable assignments (`x := y` also contains a
-- colon, so `:=`/`?=`/`+=` lines are rejected first). Grouped by the shared name heuristic.
--
---@module "lvim-build.recipes.make"

local context = require("lvim-build.context")
local util = require("lvim-build.recipes.util")

-- A generous cap: a generated Makefile can declare hundreds of internal targets.
local MAX_TARGETS = 30

---@type LvimBuildRecipe
return {
    name = "make",
    kind = "project",
    markers = { "Makefile", "makefile", "GNUmakefile" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "Makefile", "makefile", "GNUmakefile" })
        local lines = marker and context.readlines(marker) or nil
        if not lines then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local seen, out = {}, {}
        for _, line in ipairs(lines) do
            if not line:find("[:?+]=") then
                local target = line:match("^([%w][%w%._%-/]*)%s*:")
                if target and not seen[target] and not target:find("[%%$]") then
                    seen[target] = true
                    out[#out + 1] = {
                        name = "make " .. target,
                        group = util.group_of(target),
                        cmd = { "make", target },
                        cwd = cwd,
                        matcher = "gcc",
                    }
                    if #out >= MAX_TARGETS then
                        break
                    end
                end
            end
        end
        return out
    end,
}

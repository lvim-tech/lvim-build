-- lvim-build.highlights: the chooser's group badges / text zones, self-themed from the
-- lvim-utils palette. One accent per action GROUP (from config.colors: Build=blue, Run=green,
-- Test=yellow, Bench=magenta, Lint=cyan), each lead badge a tint of its accent toward the editor
-- bg (the shared "mtint" convention). The section fold headers take the same accents through the
-- shared lvim-utils.highlight.section_accent (via lvim-ui.section) — nothing section-specific is
-- defined here. build() is bound via lvim-utils.highlight.bind in setup(), re-derived on
-- ColorScheme / palette sync.
--
---@module "lvim-build.highlights"

local c = require("lvim-utils.colors")
local hl = require("lvim-utils.highlight")
local config = require("lvim-build.config")

local M = {}

--- Blend an accent toward the editor bg (the shared "mtint" convention).
---@param accent string
---@param t number
---@return string
local function mtint(accent, t)
    return hl.blend(accent, c.bg, t)
end

--- Resolve a `config.colors` value to a real colour: a palette KEY (`c[key]`, tracks the live
--- theme) or, when it is not a palette field, the value itself (a literal "#rrggbb").
---@param key string
---@return string
local function accent(key)
    local v = c[key]
    return type(v) == "string" and v or key
end

--- The lvim-build highlight groups from the live palette + `config.colors`.
---@return table<string, table>
function M.build()
    local groups = {
        -- row text zones
        LvimBuildText = { fg = c.fg },
        LvimBuildDim = { fg = mtint(c.fg, 0.6) },
        LvimBuildEmpty = { fg = mtint(c.fg, 0.5), italic = true },
    }
    -- one badge + name pair per action group (LvimBuildBuildBadge, LvimBuildRunName, …)
    for group, key in pairs(config.colors) do
        local col = accent(key)
        groups["LvimBuild" .. group .. "Badge"] = { fg = col, bg = mtint(col, 0.3), bold = true }
        groups["LvimBuild" .. group .. "Name"] = { fg = col }
    end
    return groups
end

return M

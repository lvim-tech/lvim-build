-- lvim-build.recipes.util: the tiny helpers the recipe files share — the target-name → group
-- heuristic (make targets, just recipes, npm scripts all classify the same way) and a shell
-- single-quote escaper for string commands.
--
---@module "lvim-build.recipes.util"

local M = {}

-- Ordered (pattern → group) heuristics for a target/script NAME. First hit wins; "Build" is the
-- fallback (a bare `make <target>` most often builds something).
local GROUPS = {
    { "test", "Test" },
    { "spec", "Test" },
    { "bench", "Bench" },
    { "lint", "Lint" },
    { "fmt", "Lint" },
    { "format", "Lint" },
    { "check", "Lint" },
    { "run", "Run" },
    { "start", "Run" },
    { "serve", "Run" },
    { "dev", "Run" },
    { "watch", "Run" },
    { "preview", "Run" },
}

--- Classify a target/script name into a chooser group.
---@param name string
---@return string group
function M.group_of(name)
    local low = name:lower()
    for _, g in ipairs(GROUPS) do
        if low:find(g[1], 1, true) then
            return g[2]
        end
    end
    return "Build"
end

--- POSIX single-quote `s` for embedding in a string command run through the shell.
---@param s string
---@return string
function M.q(s)
    return "'" .. s:gsub("'", [['\'']]) .. "'"
end

return M

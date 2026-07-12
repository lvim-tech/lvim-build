-- lvim-build: :checkhealth lvim-build.
-- Diagnoses what makes detection/execution misbehave invisibly: the REQUIRED lvim-tasks backend
-- (build only describes actions — tasks runs them), the lvim-ui / lvim-utils chassis, the sqlite
-- usage store (warn-only — memory degrades to session-only), which toolchains are actually on
-- PATH (a recipe can only offer what the shell can run), what the CURRENT context detects, and a
-- config sanity pass. Read-only reporting — never mutates config or state.
--
---@module "lvim-build.health"

local config = require("lvim-build.config")

local M = {}

-- Toolchains the built-in recipes shell out to (name → the recipe that wants it).
local TOOLS = {
    { "cargo", "cargo" },
    { "make", "make" },
    { "cmake", "cmake" },
    { "npm", "node" },
    { "go", "go" },
    { "just", "just" },
    { "meson", "meson" },
    { "gradle", "gradle (a project ./gradlew wrapper also works)" },
    { "mvn", "maven" },
    { "gcc", "c (single file)" },
    { "g++", "cpp (single file)" },
    { "rustc", "rust (single file)" },
    { "python3", "python (single file)" },
    { "pytest", "python (pyproject)" },
    { "ruff", "python lint" },
}

--- Validate the live config table; error per violation, ok when clean.
---@param health table  the vim.health reporter
local function check_config(health)
    local problems = 0
    local layouts = { float = true, area = true, bottom = true }
    if not layouts[config.layout] then
        problems = problems + 1
        health.error(("config.layout '%s' is not one of float/area/bottom"):format(tostring(config.layout)))
    end
    if config.save ~= false and config.save ~= "current" and config.save ~= "all" then
        problems = problems + 1
        health.error('config.save must be "current", "all" or false')
    end
    if type(config.order) ~= "table" or #config.order == 0 then
        problems = problems + 1
        health.error("config.order must be a non-empty list of group names")
    end
    for _, g in ipairs(config.order) do
        if not config.colors[g] then
            problems = problems + 1
            health.warn(("group '%s' has no accent in config.colors (badge falls back oddly)"):format(g))
        end
    end
    if problems == 0 then
        health.ok("config valid")
    end
end

--- Run the health report.
function M.check()
    local health = vim.health
    health.start("lvim-build")

    if vim.fn.has("nvim-0.11") == 1 then
        health.ok("Neovim >= 0.11")
    else
        health.error("Neovim >= 0.11 is required (vim.fs.root/find, and lvim-tasks needs it)")
    end

    -- lvim-tasks is the REQUIRED execution backend
    if pcall(require, "lvim-tasks") then
        health.ok("lvim-tasks found (execution backend)")
    else
        health.error("lvim-tasks not found — lvim-build can detect but cannot RUN anything")
    end

    -- the chooser chassis
    local ok_ui = pcall(require, "lvim-ui")
    local ok_utils = pcall(require, "lvim-utils.utils")
    if ok_ui and ok_utils then
        health.ok("lvim-ui + lvim-utils found (chooser / palette / store)")
    else
        health.error("lvim-ui / lvim-utils not found — the chooser cannot open")
    end

    -- the usage store (warn-only: memory degrades to session-only without sqlite)
    local ok_store, store = pcall(require, "lvim-utils.store")
    if ok_store then
        store.health(health, false)
    end
    if require("lvim-build.memory").persistent() then
        health.ok("usage store open (frecency + redo survive restarts)")
    else
        health.warn("usage store unavailable — frecency/redo memory is session-only")
    end

    -- toolchains on PATH
    for _, t in ipairs(TOOLS) do
        if vim.fn.executable(t[1]) == 1 then
            health.ok(("%s on PATH (%s)"):format(t[1], t[2]))
        else
            health.info(("%s not on PATH — the %s actions stay hidden/failing"):format(t[1], t[2]))
        end
    end

    -- what THIS context detects
    local ctx = require("lvim-build.context").get()
    local actions = require("lvim-build.detect").actions(ctx)
    health.info(("current context: root=%s ft=%s → %d action(s)"):format(ctx.root, ctx.ft, #actions))

    check_config(health)

    if not config.single_file then
        health.info("single-file fallbacks are off (config.single_file = false)")
    end
end

return M

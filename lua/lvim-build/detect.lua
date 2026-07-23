-- lvim-build.detect: run every recipe's `detect(ctx)` and collect the applicable ACTIONS.
-- Detection is synchronous but cheap: each recipe stats its root markers first and parses a file
-- (Makefile targets, package.json scripts) only when its marker exists. PROJECT-level results are
-- cached per root and invalidated by a marker mtime STAMP (the paths + mtimes of every marker the
-- recipes declare) — so retyping `:LvimBuild` re-parses nothing until a marker file changes.
-- Single-FILE fallbacks depend on the current buffer and are recomputed every call (they parse
-- nothing). User recipes (`config.recipes`) run with the built-ins, overriding by name.
--
---@module "lvim-build.detect"

local config = require("lvim-build.config")
local context = require("lvim-build.context")

local M = {}

---@class LvimBuildAction
---@field name    string        Display + memory key ("cargo build", "make test", …)
---@field group   string        Chooser group ("Build"|"Run"|"Test"|"Bench"|"Lint")
---@field cmd     string|string[]  The command (argv list, or a string through the shell)
---@field cwd     string?       Working directory
---@field env     table<string,string>?
---@field matcher string?       lvim-tasks problem-matcher name / errorformat

---@class LvimBuildRecipe
---@field name    string
---@field kind    "project"|"file"  project = root-marker driven (cached); file = current-buffer fallback
---@field markers string[]?     The marker file names the detection stats/parses (the cache stamp)
---@field watch?  fun(ctx: LvimBuildContext): string  Extra cache-stamp input (optional) — see below
---@field detect  fun(ctx: LvimBuildContext): LvimBuildAction[]

-- `watch` exists because a recipe's actions can depend on state its MARKERS do not describe. The
-- Python recipe is the case that forced it: its actions are resolved through the project's
-- virtualenv and lockfile, so `uv sync` (which creates .venv/ and uv.lock, touching no marker)
-- changes what should be offered — yet the marker stamp is unchanged, so the cache would keep
-- serving the pre-sync action list until an unrelated marker edit or a restart. A recipe returns
-- from `watch` any string that changes when its inputs change (conventionally path@mtime pairs);
-- it is folded into the cache stamp. It never marks a project — only invalidates.

-- The built-in detectors. Project recipes first (their actions lead), then the single-file
-- fallbacks. Loaded once — each module is data + one detect function, no state.
---@type string[]
local BUILTIN = {
    "cargo",
    "make",
    "cmake",
    "node",
    "go",
    "zig",
    "dart",
    "swift",
    "just",
    "meson",
    "gradle",
    "maven",
    "dotnet",
    "php",
    "python",
    "ruby",
    "c",
    "cpp",
    "rust_single",
    "python_single",
    "kotlin",
    "lua",
    "shell",
}

---@type LvimBuildRecipe[]?  the resolved recipe list (built-ins + user overrides), built lazily
local resolved = nil

--- The effective recipe list: built-ins overlaid with `config.recipes` by name (a user recipe
--- with a built-in's name replaces it; new names append).
---@return LvimBuildRecipe[]
local function recipes()
    if resolved then
        return resolved
    end
    local by_name, order = {}, {}
    for _, name in ipairs(BUILTIN) do
        local r = require("lvim-build.recipes." .. name)
        by_name[r.name] = r
        order[#order + 1] = r.name
    end
    for name, r in pairs(config.recipes) do
        if type(r) == "table" and type(r.detect) == "function" then
            r.name = r.name or name
            r.kind = r.kind or "project"
            if not by_name[name] then
                order[#order + 1] = name
            end
            by_name[name] = r
        end
    end
    resolved = {}
    for _, name in ipairs(order) do
        resolved[#resolved + 1] = by_name[name]
    end
    return resolved
end

--- Drop the resolved recipe list (setup() calls this after merging user recipes).
function M.reset()
    resolved = nil
end

---@type table<string, { stamp: string, actions: LvimBuildAction[] }>  per-root project cache
local cache = {}

--- The invalidation stamp for `ctx`: every project recipe's nearest marker path + mtime. A
--- marker appearing, disappearing or being edited changes the stamp → re-detect.
---@param ctx LvimBuildContext
---@return string
local function stamp_of(ctx)
    local parts = {}
    for _, r in ipairs(recipes()) do
        if r.kind == "project" then
            for _, name in ipairs(r.markers or {}) do
                local path = context.marker(ctx, name)
                if path then
                    parts[#parts + 1] = path .. "@" .. context.mtime(path)
                end
            end
            -- …plus whatever else the recipe's actions depend on (a virtualenv, a lockfile).
            if type(r.watch) == "function" then
                local ok, extra = pcall(r.watch, ctx)
                if ok and type(extra) == "string" and extra ~= "" then
                    parts[#parts + 1] = extra
                end
            end
        end
    end
    return table.concat(parts, "|")
end

--- Every action applicable to `ctx`: cached project actions + fresh single-file fallbacks
--- (`config.single_file`). Actions keep recipe emission order; the chooser groups + sorts them.
---@param ctx LvimBuildContext?
---@return LvimBuildAction[]
function M.actions(ctx)
    ctx = ctx or context.get()
    local stamp = stamp_of(ctx)
    local entry = cache[ctx.root]
    local project
    if entry and entry.stamp == stamp then
        project = entry.actions
    else
        project = {}
        for _, r in ipairs(recipes()) do
            if r.kind == "project" then
                local ok, actions = pcall(r.detect, ctx)
                if ok then
                    vim.list_extend(project, actions or {})
                else
                    vim.notify_once(
                        ("lvim-build: recipe %q failed to detect: %s"):format(r.name, tostring(actions)),
                        vim.log.levels.WARN
                    )
                end
            end
        end
        cache[ctx.root] = { stamp = stamp, actions = project }
    end
    local out = vim.list_extend({}, project)
    if config.single_file then
        for _, r in ipairs(recipes()) do
            if r.kind == "file" then
                local ok, actions = pcall(r.detect, ctx)
                if ok then
                    vim.list_extend(out, actions or {})
                else
                    vim.notify_once(
                        ("lvim-build: recipe %q failed to detect: %s"):format(r.name, tostring(actions)),
                        vim.log.levels.WARN
                    )
                end
            end
        end
    end
    return out
end

return M

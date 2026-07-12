-- lvim-build.memory: the usage store — which action you ran, where, how often, how recently.
-- Powers the chooser's FRECENCY ordering (your daily `cargo run` floats to the top of its group)
-- and `:LvimBuild redo`/`last` (the most recently used action per project root). Sqlite via the
-- shared lvim-utils.store wrapper, OWN db at stdpath("data")/lvim-build/ (the per-plugin
-- persistence canon); when sqlite.lua is absent it degrades to a session-only in-memory table —
-- redo still works within the session, health warns. One upsert per run, reads are per chooser
-- open (never a hot path).
--
---@module "lvim-build.memory"

local M = {}

---@class LvimBuildUsage
---@field count integer      how many times the action ran here
---@field last_used integer  os.time() of the last run

---@type table?  the lvim-utils.store handle (nil until opened / when sqlite is unavailable)
local db = nil
---@type boolean
local opened = false

--- Session fallback (and write-through cache): root → action name → usage.
---@type table<string, table<string, LvimBuildUsage>>
local mem = {}

local SCHEMA = {
    id = { "integer", primary = true, autoincrement = true },
    root = { "text" },
    ft = { "text" },
    name = { "text" },
    count = { "integer" },
    last_used = { "integer" },
}

--- Open the store lazily (once); nil when the sqlite backend is unavailable / did not open.
---@return table?
local function ensure()
    if opened then
        return db
    end
    opened = true
    local ok, store = pcall(require, "lvim-utils.store")
    if not ok or not store.available() then
        return nil
    end
    db = store.new({
        backend = "sqlite",
        name = "lvim-build",
        version = 1,
        tables = { usage = SCHEMA },
    })
    if not (db and db:is_open()) then
        db = nil
    end
    return db
end

--- The in-memory usage map for `root`, seeded from the db on first touch this session.
---@param root string
---@return table<string, LvimBuildUsage>
local function usage_of(root)
    local u = mem[root]
    if u then
        return u
    end
    u = {}
    mem[root] = u
    local store = ensure()
    if store then
        local rows = store:find("usage", { root = root })
        for _, r in ipairs(type(rows) == "table" and rows or {}) do
            u[r.name] = { count = r.count or 0, last_used = r.last_used or 0 }
        end
    end
    return u
end

--- Record one run of `name` under `root` (upsert count+1, stamp last_used).
---@param root string
---@param ft string
---@param name string
function M.record(root, ft, name)
    local u = usage_of(root)
    local rec = u[name] or { count = 0, last_used = 0 }
    rec.count = rec.count + 1
    rec.last_used = os.time()
    u[name] = rec
    local store = ensure()
    if store then
        local rows = store:find("usage", { root = root, name = name })
        if type(rows) == "table" and rows[1] then
            store:update("usage", { id = rows[1].id }, { count = rec.count, last_used = rec.last_used, ft = ft })
        else
            store:insert("usage", { root = root, ft = ft, name = name, count = 1, last_used = rec.last_used })
        end
    end
end

--- The frecency SCORE of `name` under `root` (0 for a never-run action): the usage count plus a
--- recency bonus that decays over a week — so a rarely-used but just-run action still leads.
---@param root string
---@param name string
---@return number
function M.score(root, name)
    local rec = usage_of(root)[name]
    if not rec then
        return 0
    end
    local age_days = (os.time() - rec.last_used) / 86400
    return rec.count + math.max(0, 7 - age_days)
end

--- The most recently RUN action name under `root` (the redo target), or nil.
---@param root string
---@return string?
function M.last(root)
    local best, when = nil, 0
    for name, rec in pairs(usage_of(root)) do
        if rec.last_used > when then
            best, when = name, rec.last_used
        end
    end
    return best
end

--- Whether the durable sqlite backend is active (for :checkhealth; false = session-only memory).
---@return boolean
function M.persistent()
    return ensure() ~= nil
end

return M

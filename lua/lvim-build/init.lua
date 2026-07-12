-- lvim-build: "just compile/run/test THIS" — detect what the current file/project is (cargo,
-- make, cmake, npm scripts, go, just, meson, gradle/maven, pyproject, single-file c/c++/rust/
-- python/lua/shell), offer every applicable action in ONE chooser (grouped Build/Run/Test/Bench/
-- Lint sections, frecency-ordered within each group), execute through lvim-tasks (a HARD
-- dependency: build detects and DESCRIBES; tasks RUNS and displays — output panel, spinner,
-- restart and problem-matcher → quickfix all inherited), and remember the choice so `:LvimBuild
-- redo` re-runs it with no UI. This module is the public seam: `setup()`, `:LvimBuild`, and the
-- chooser/execute flow; detection lives in detect.lua + recipes/, usage memory in memory.lua.
--
---@module "lvim-build"

local api = vim.api
local config = require("lvim-build.config")
local context = require("lvim-build.context")
local detect = require("lvim-build.detect")
local memory = require("lvim-build.memory")
local highlights = require("lvim-build.highlights")
local merge = require("lvim-utils.utils").merge
local hl = require("lvim-utils.highlight")
local ui = require("lvim-ui")
local iconlib = require("lvim-utils.icons")

local M = {}

---@type boolean  setup() ran (command registered)
local registered = false

---@type string?  session-sticky per-command layout override
local sticky_layout = nil

---@param msg string
---@param level integer?
local function notify(msg, level)
    vim.notify("lvim-build: " .. msg, level or vim.log.levels.INFO)
end

-- ── execution ────────────────────────────────────────────────────────────────

--- Pre-run save, per `config.save`: "current" updates the current buffer, "all" writes every
--- modified one. Silent — an unwritable buffer must not abort the build.
local function save_buffers()
    if config.save == "current" then
        if vim.bo.modified and vim.bo.buftype == "" then
            pcall(vim.cmd.update, { mods = { silent = true } })
        end
    elseif config.save == "all" then
        pcall(vim.cmd.wall, { mods = { silent = true } })
    end
end

--- Run `action`: save, record the usage (frecency + redo), hand the spec to lvim-tasks.
---@param ctx LvimBuildContext
---@param action LvimBuildAction
---@return boolean started
local function execute(ctx, action)
    local ok, tasks = pcall(require, "lvim-tasks")
    if not ok then
        notify("lvim-tasks is required to run actions (install lvim-tech/lvim-tasks)", vim.log.levels.ERROR)
        return false
    end
    save_buffers()
    memory.record(ctx.root, ctx.ft, action.name)
    tasks.run({
        name = action.name,
        cmd = action.cmd,
        cwd = action.cwd,
        env = action.env,
        matcher = action.matcher,
        group = action.group,
        -- the template key groups this action's runs in the tasks history (avg duration → ETA)
        template = "build: " .. action.name,
    })
    return true
end

-- ── the chooser ──────────────────────────────────────────────────────────────

--- The lead badge for an action row: the current file's filetype icon (via lvim-utils.icons →
--- the lvim-icons provider), falling back to the generic action glyph.
---@param ctx LvimBuildContext
---@return string
local function action_icon(ctx)
    local icon = iconlib.get(ctx.file ~= "" and ctx.file or "x.txt", {}).glyph
    if not icon or icon == "" then
        icon = config.icons.action
    end
    return icon
end

--- Group the detected actions per `config.order` (unknown groups append, detection order).
---@param actions LvimBuildAction[]
---@return string[] groups, table<string, LvimBuildAction[]> by_group
local function grouped(actions)
    local by_group, groups = {}, {}
    local known = {}
    for _, g in ipairs(config.order) do
        known[g] = true
    end
    for _, a in ipairs(actions) do
        local g = a.group or "Build"
        if not by_group[g] then
            by_group[g] = {}
            if not known[g] then
                groups[#groups + 1] = g -- an unknown group still shows (after the ordered ones)
            end
        end
        by_group[g][#by_group[g] + 1] = a
    end
    local ordered = {}
    for _, g in ipairs(config.order) do
        if by_group[g] then
            ordered[#ordered + 1] = g
        end
    end
    vim.list_extend(ordered, groups)
    return ordered, by_group
end

--- Open the action chooser: one collapsible SECTION per group (the canonical ui.section fold
--- header, accented per group), children frecency-ordered. Selecting runs the action AND records
--- the usage.
---@param only_group string?  restrict to one group (`:LvimBuild Test`)
---@param layout string?      per-command layout override (session-sticky)
function M.open(only_group, layout)
    if layout then
        sticky_layout = layout
    end
    local ctx = context.get()
    local actions = detect.actions(ctx)
    if only_group then
        actions = vim.tbl_filter(function(a)
            return (a.group or "Build") == only_group
        end, actions)
    end
    if #actions == 0 then
        notify(only_group and ("no %s actions here"):format(only_group) or "nothing to build/run here")
        return
    end

    local order, by_group = grouped(actions)
    local icon = action_icon(ctx)
    local last_name = memory.last(ctx.root)
    local rows, initial_row = {}, nil
    local index = {} ---@type table<string, LvimBuildAction>  row name → action
    for _, group in ipairs(order) do
        local list = by_group[group]
        -- frecency: usage count + recency bonus, then stable by name
        table.sort(list, function(a, b)
            local sa, sb = memory.score(ctx.root, a.name), memory.score(ctx.root, b.name)
            if sa ~= sb then
                return sa > sb
            end
            return a.name < b.name
        end)
        local namew = 8
        for _, a in ipairs(list) do
            namew = math.max(namew, vim.fn.strdisplaywidth(a.name))
        end
        namew = math.min(namew, 32)
        local children = {}
        for _, a in ipairs(list) do
            local rname = "act_" .. group .. "_" .. a.name
            index[rname] = a
            if a.name == last_name and not initial_row then
                initial_row = rname -- focus the redo target on open
            end
            local cmd = type(a.cmd) == "table" and table.concat(a.cmd --[[@as string[] ]], " ") or tostring(a.cmd)
            local label = (" %-" .. namew .. "s"):format(a.name)
            local spans = { { 1, 1 + #label, "LvimBuild" .. group .. "Name" } }
            children[#children + 1] = {
                type = "action",
                name = rname,
                flat = true,
                tight = true,
                icon = " " .. icon .. " ",
                icon_hl = "LvimBuild" .. group .. "Badge",
                label = label,
                -- the dim cmd preview — only when it SAYS more than the name already does
                suffix = cmd ~= a.name and vim.fn.strcharpart(cmd, 0, 48) or nil,
                suffix_hl = "LvimBuildDim",
                label_spans = spans,
                run = function(_, close)
                    close(true, { row = rname })
                end,
            }
        end
        rows[#rows + 1] = ui.section({
            name = "grp_" .. group,
            icon = " " .. config.icons.expand_open .. " ",
            box_hl = "LvimBuild" .. group .. "Badge",
            label = group,
            count = #children,
            accent = config.colors[group] or "blue",
            expanded = true,
            children = children,
        })
    end

    ui.tabs({
        title = { icon = config.icons.build, text = config.title },
        title_pos = config.title_pos,
        tabs = { { label = config.title, icon = config.icons.build, menu = true, rows = rows } },
        layout = sticky_layout or config.layout,
        pad = 0, -- the badges carry their own gutter; the list sits flush
        cursorline_hl = "LvimUiCursorLine",
        initial_row = initial_row,
        callback = function(confirmed, result)
            local action = confirmed == true and type(result) == "table" and index[result.row] or nil
            if action then
                -- scheduled: run AFTER the chooser teardown fully unwinds (save + jobstart)
                vim.schedule(function()
                    execute(ctx, action)
                end)
            end
        end,
    })
end

-- ── redo / last ──────────────────────────────────────────────────────────────

--- Re-run the project's most recent action WITHOUT UI (the daily-driver keybind). The action is
--- re-DETECTED (never replayed from a stale cmd), so a renamed/removed target falls back to the
--- chooser.
function M.redo()
    local ctx = context.get()
    local name = memory.last(ctx.root)
    if not name then
        notify("nothing to redo here yet — pick an action first")
        M.open()
        return
    end
    for _, a in ipairs(detect.actions(ctx)) do
        if a.name == name then
            execute(ctx, a)
            return
        end
    end
    notify(("'%s' no longer applies here — pick again"):format(name), vim.log.levels.WARN)
    M.open()
end

--- Show (not run) the project's last action in the statusline overlay for a moment.
function M.last()
    local ctx = context.get()
    local name = memory.last(ctx.root)
    if not name then
        notify("no action recorded for this project yet")
        return
    end
    local ok, overlay = pcall(require, "lvim-hud.overlay")
    if ok and overlay.is_enabled and overlay.is_enabled() then
        overlay.set({ icon = config.icons.build, title = "redo: " .. name })
        vim.defer_fn(function()
            -- clear only OUR message (another owner may have taken the line meanwhile)
            local live = overlay.get and overlay.get()
            if live and live.title == "redo: " .. name then
                overlay.clear()
            end
        end, 3000)
    else
        notify("redo: " .. name)
    end
end

-- ── setup / command ──────────────────────────────────────────────────────────

---@type table<string, boolean>
local LAYOUTS = { float = true, area = true, bottom = true }

--- Parse `:LvimBuild` args: a layout token anywhere; the rest is redo/last or a group name.
---@param args string
---@return string? sub, string? layout
local function parse(args)
    local sub, layout = nil, nil
    for tok in args:gmatch("%S+") do
        if LAYOUTS[tok] then
            layout = tok
        elseif not sub then
            sub = tok
        end
    end
    return sub, layout
end

--- Configure lvim-build: merge `opts` into the live config, bind the theme factory, register
--- `:LvimBuild`. Idempotent past the first call.
---@param opts LvimBuildConfig?
function M.setup(opts)
    if opts then
        merge(config, opts)
        detect.reset() -- user recipes may have changed
    end
    if registered then
        return
    end
    registered = true
    hl.setup()
    hl.bind(highlights.build)

    api.nvim_create_user_command("LvimBuild", function(cmd)
        local sub, layout = parse(cmd.args)
        if sub == "redo" then
            M.redo()
        elseif sub == "last" then
            M.last()
        else
            -- a group name filters the chooser; anything unknown falls through to the full chooser
            local group = nil
            for _, g in ipairs(config.order) do
                if sub and g:lower() == sub:lower() then
                    group = g
                    break
                end
            end
            if sub and not group then
                notify(("unknown argument '%s' — showing everything"):format(sub), vim.log.levels.WARN)
            end
            M.open(group, layout)
        end
    end, {
        nargs = "*",
        desc = "lvim-build: chooser / redo / last / <group> [float|area|bottom]",
        complete = function()
            local out = { "redo", "last" }
            vim.list_extend(out, config.order)
            return vim.list_extend(out, { "float", "area", "bottom" })
        end,
    })
end

return M

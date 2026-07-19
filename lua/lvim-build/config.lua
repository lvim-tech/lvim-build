-- lvim-build: the live configuration table.
-- Holds the defaults; setup() merges user overrides into it IN PLACE (via
-- lvim-utils.utils.merge), so every require("lvim-build.config") reader sees the effective
-- values.
--
---@module "lvim-build.config"

---@class LvimBuildConfig
---@field layout      "float"|"area"|"bottom"  Default chooser layout
---@field title       string   Chooser title
---@field title_pos   "left"|"center"|"right"  Chooser title alignment
---@field save        "current"|"all"|false  What to write before running an action
---@field single_file boolean  Enable the no-project single-file fallbacks (gcc/g++/rustc/python/…)
---@field memory_retention_days integer  Prune usage rows not run in this many days (0 = keep forever)
---@field recipes     table<string, LvimBuildRecipe>  Extra user detectors (same shape as built-ins)
---@field order       string[] Group display order in the chooser
---@field colors      table<string, string>  Group accents (lvim-utils palette keys or "#rrggbb")
---@field icons       table    Chooser glyphs (Nerd Font single-width)

---@type LvimBuildConfig
return {
    -- Where the action chooser opens (a quick modal pick — float by default). A layout token on
    -- the command (`:LvimBuild bottom`) overrides it for the session.
    layout = "float",
    -- Chooser border/overlay title and its alignment.
    title = "Build",
    title_pos = "left",
    -- Write before running: "current" updates the current buffer, "all" runs :wall, false skips.
    save = "current",
    -- Offer the single-file fallbacks (compile/run THIS buffer via gcc/g++/rustc/python/nvim -l/
    -- bash) when no project marker owns the file.
    single_file = true,
    -- Prune usage rows not run in this many days on the first store open each session (keeps the
    -- frecency db from accreting rows for deleted projects / renamed actions forever). 0 disables it.
    memory_retention_days = 180,
    -- Extra user detectors, merged over the built-ins by name (same recipe shape — see README).
    recipes = {},
    -- The group order in the chooser (groups a detection did not produce are skipped).
    order = { "Build", "Run", "Test", "Bench", "Lint" },
    -- Group accents: lvim-utils palette keys (track the live theme) or literal "#rrggbb".
    colors = {
        Build = "blue",
        Run = "green",
        Test = "yellow",
        Bench = "magenta",
        Lint = "cyan",
    },
    -- Chooser glyphs (single-width Nerd Font; the fold carets come from the shared section canon).
    icons = {
        build = "󰏗", -- the chooser / overlay lead glyph
        action = "󰐊", -- fallback lead glyph for an action row without a filetype icon
        expand_open = "", -- section caret, expanded
        expand_closed = "", -- section caret, collapsed
    },
}

-- lvim-build.recipes.clojure: a Clojure project (deps.edn / project.clj / build.boot upward of the
-- file/cwd) — Run / Test through the project's build tool, plus cljfmt (Format) and clj-kondo (Lint).
-- The Clojure CLI has no canonical run/test verb (projects wire ALIASES in deps.edn), so the CLI
-- actions target the conventional `:run` / `:test` aliases (`clojure -M:run` / `clojure -X:test`);
-- Leiningen and Boot use their built-in `run` / `test` subcommands. Detection prefers the Clojure CLI
-- when several markers coexist. When lvim-lang is installed and its Clojure provider is active, the
-- `clojure` / `lein` / `boot` binary is resolved through `lvim-lang.core.toolchain` first (honouring a
-- version manager / an explicit SDK), then PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.clojure"

local context = require("lvim-build.context")

--- Resolve `tool` ("clojure" | "lein" | "boot"): the lvim-lang Clojure toolchain when active for
--- `root`, else the bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("clojure", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "clojure",
    kind = "project",
    markers = { "deps.edn", "project.clj", "build.boot" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        -- Priority: the Clojure CLI (deps.edn) → Leiningen (project.clj) → Boot (build.boot).
        local deps = context.marker(ctx, "deps.edn")
        local lein = context.marker(ctx, "project.clj")
        local boot = context.marker(ctx, "build.boot")
        local marker = deps or lein or boot
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)

        ---@type LvimBuildAction[]
        local actions = {}
        local function act(name, group, argv)
            actions[#actions + 1] = { name = name, group = group, cmd = argv, cwd = cwd, matcher = "generic" }
        end

        if deps then
            local clojure = bin("clojure", cwd)
            act("clojure -M:run", "Run", { clojure, "-M:run" })
            act("clojure -X:test", "Test", { clojure, "-X:test" })
        elseif lein then
            local lein_bin = bin("lein", cwd)
            act("lein run", "Run", { lein_bin, "run" })
            act("lein test", "Test", { lein_bin, "test" })
        else
            local boot_bin = bin("boot", cwd)
            act("boot run", "Run", { boot_bin, "run" })
            act("boot test", "Test", { boot_bin, "test" })
        end

        -- cljfmt (format) + clj-kondo (lint) apply to any Clojure project (found on PATH at run time).
        act("cljfmt fix", "Format", { "cljfmt", "fix" })
        act("clj-kondo --lint src", "Lint", { "clj-kondo", "--lint", "src" })

        return actions
    end,
}

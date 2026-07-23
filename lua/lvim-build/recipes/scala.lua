-- lvim-build.recipes.scala: a Scala project — build/run/test via sbt (`build.sbt`) or mill
-- (`build.sc`), plus a scalafmt format action. sbt is the near-universal Scala build system; mill is
-- the alternative. The project WRAPPER (`./sbt` / `./mill`) is preferred when present (it pins the
-- exact tool version), else — when lvim-lang is installed and its Scala provider is active — the
-- binary resolved through `lvim-lang.core.toolchain` (honouring SDKMAN / a version manager / an
-- explicit SDK), else the bare name (found on PATH at run time by lvim-tasks). mill addresses a module
-- for `run`, so a Run action is offered only for sbt; build/test map cleanly on both. lvim-build works
-- fully without lvim-lang.
--
---@module "lvim-build.recipes.scala"

local context = require("lvim-build.context")

--- Resolve a build/tool binary for `root`: the project wrapper (`./sbt` / `./mill`) when present, else
--- the lvim-lang Scala toolchain when active, else the bare name.
---@param tool string  "sbt" | "mill" | "scalafmt"
---@param root string
---@return string
local function bin(tool, root)
    if tool == "sbt" or tool == "mill" then
        local wrapper = vim.fs.joinpath(root, tool)
        if vim.fn.executable(wrapper) == 1 then
            return "./" .. tool
        end
    end
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("scala", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "scala",
    kind = "project",
    markers = { "build.sbt", "build.sc" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local sbt = context.marker(ctx, "build.sbt")
        local mill = context.marker(ctx, "build.sc")
        local marker = sbt or mill
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local fmt = bin("scalafmt", cwd)
        local actions

        if sbt then
            local s = bin("sbt", cwd)
            actions = {
                { name = s .. " compile", group = "Build", cmd = { s, "compile" }, cwd = cwd, matcher = "generic" },
                { name = s .. " run", group = "Run", cmd = { s, "run" }, cwd = cwd, matcher = "generic" },
                { name = s .. " test", group = "Test", cmd = { s, "test" }, cwd = cwd, matcher = "generic" },
            }
        else
            local m = bin("mill", cwd)
            -- mill `run` needs a module (`<module>.run`), which a stateless recipe can't know — offer
            -- build/test over all modules; Run for mill is driven through lvim-lang (mill_module).
            actions = {
                {
                    name = m .. " __.compile",
                    group = "Build",
                    cmd = { m, "__.compile" },
                    cwd = cwd,
                    matcher = "generic",
                },
                { name = m .. " __.test", group = "Test", cmd = { m, "__.test" }, cwd = cwd, matcher = "generic" },
            }
        end

        -- scalafmt formats the project's Scala sources per the discovered `.scalafmt.conf`.
        actions[#actions + 1] =
            { name = "scalafmt", group = "Lint", cmd = { fmt, "--non-interactive" }, cwd = cwd, matcher = "generic" }
        return actions
    end,
}

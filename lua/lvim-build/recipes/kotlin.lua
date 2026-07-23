-- lvim-build.recipes.kotlin: single-file Kotlin fallback — a `.kt` / `.kts` buffer OUTSIDE any
-- Gradle / Maven project (a build script upward wins, gradle.lua / maven.lua handle those) is
-- compiled / run directly with the Kotlin CLI. A `.kts` script runs straight through `kotlin`; a
-- `.kt` with a top-level `main()` is compiled to a runnable jar with `kotlinc -include-runtime` (the
-- manifest main class is set for a single `main`) and run with `java -jar`. The compiled jar lands in
-- the shared single-file cache dir. When lvim-lang is installed and its Kotlin provider is active,
-- the `kotlinc` / `kotlin` / `java` binary is resolved through `lvim-lang.core.toolchain` first
-- (honouring SDKMAN / a version manager / an explicit SDK), then PATH; lvim-build works fully without
-- lvim-lang.
--
---@module "lvim-build.recipes.kotlin"

local context = require("lvim-build.context")
local util = require("lvim-build.recipes.util")

--- Resolve `tool` ("kotlinc" | "kotlin" | "java"): the lvim-lang Kotlin toolchain when active for
--- `root`, else the bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("kotlin", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "kotlin",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if ctx.ft ~= "kotlin" or ctx.file == "" then
            return {}
        end
        -- A Gradle / Maven project owns the file → its recipe handles build/run/test, not this one.
        if
            context.marker(
                ctx,
                { "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "pom.xml" }
            )
        then
            return {}
        end
        local cwd = vim.fs.dirname(ctx.file)

        -- A Kotlin SCRIPT (.kts) runs directly through the `kotlin` runner.
        if ctx.file:match("%.kts$") then
            local kotlin = bin("kotlin", cwd)
            return {
                { name = "kotlin script", group = "Run", cmd = { kotlin, ctx.file }, cwd = cwd, matcher = "generic" },
            }
        end

        -- A plain .kt: compile to a runnable jar, then run it on the JVM.
        local kotlinc = bin("kotlinc", cwd)
        local java = bin("java", cwd)
        local jar = context.cache_dir() .. "/" .. vim.fn.fnamemodify(ctx.file, ":t:r") .. ".jar"
        local compile = ("%s %s -include-runtime -d %s"):format(util.q(kotlinc), util.q(ctx.file), util.q(jar))
        return {
            { name = "kotlinc build", group = "Build", cmd = compile, cwd = cwd, matcher = "generic" },
            {
                name = "kotlinc build & run",
                group = "Run",
                cmd = compile .. " && " .. util.q(java) .. " -jar " .. util.q(jar),
                cwd = cwd,
                matcher = "generic",
            },
        }
    end,
}

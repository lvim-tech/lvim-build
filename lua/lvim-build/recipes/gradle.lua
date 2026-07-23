-- lvim-build.recipes.gradle: a Gradle project (basic) — build/run/test via the wrapper when the
-- project ships one (`./gradlew`, the Gradle convention), the system `gradle` otherwise. Language-
-- agnostic (Java / Kotlin / Groovy / Scala): `run` maps to the Application plugin's `run` task, so a
-- runnable Gradle app (a Kotlin `application {}` project included) is offered a Run action too.
--
---@module "lvim-build.recipes.gradle"

local context = require("lvim-build.context")

---@type LvimBuildRecipe
return {
    name = "gradle",
    kind = "project",
    markers = { "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker =
            context.marker(ctx, { "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = vim.fn.executable(cwd .. "/gradlew") == 1 and "./gradlew" or "gradle"
        return {
            { name = bin .. " build", group = "Build", cmd = { bin, "build" }, cwd = cwd, matcher = "generic" },
            { name = bin .. " run", group = "Run", cmd = { bin, "run" }, cwd = cwd, matcher = "generic" },
            { name = bin .. " test", group = "Test", cmd = { bin, "test" }, cwd = cwd, matcher = "generic" },
        }
    end,
}

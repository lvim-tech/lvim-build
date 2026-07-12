-- lvim-build.recipes.maven: a Maven project (basic) — compile/test/package on the nearest pom.
--
---@module "lvim-build.recipes.maven"

local context = require("lvim-build.context")

---@type LvimBuildRecipe
return {
    name = "maven",
    kind = "project",
    markers = { "pom.xml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "pom.xml")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        return {
            { name = "mvn compile", group = "Build", cmd = { "mvn", "compile" }, cwd = cwd, matcher = "generic" },
            { name = "mvn package", group = "Build", cmd = { "mvn", "package" }, cwd = cwd, matcher = "generic" },
            { name = "mvn test", group = "Test", cmd = { "mvn", "test" }, cwd = cwd, matcher = "generic" },
        }
    end,
}

-- lvim-build.recipes.groovy: a Gradle-driven Groovy project. Resolves `gradle` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.groovy"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("groovy", "gradle", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("gradle")
    return p ~= "" and p or "gradle"
end

---@type LvimBuildRecipe
return {
    name = "groovy",
    kind = "project",
    markers = { "build.gradle", "settings.gradle" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "build.gradle", "settings.gradle" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("gradle build", "Build", { bin, "build" }),
            act("gradle test", "Test", { bin, "test" }),
            act("gradle run", "Run", { bin, "run" }),
        }
    end,
}

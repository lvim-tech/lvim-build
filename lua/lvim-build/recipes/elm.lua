-- lvim-build.recipes.elm: a elm project. Resolves `elm` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.elm"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("elm", "elm", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("elm")
    return p ~= "" and p or "elm"
end

---@type LvimBuildRecipe
return {
    name = "elm",
    kind = "project",
    markers = { "elm.json" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "elm.json" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("elm make", "Build", { bin, "make", "src/Main.elm" }),
            act("elm-test", "Test", { "elm-test" }),
        }
    end,
}

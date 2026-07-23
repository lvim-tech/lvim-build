-- lvim-build.recipes.commonlisp: an ASDF Common Lisp system. Resolves `sbcl` through lvim-lang.core.toolchain
-- when its provider is active, else PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.commonlisp"

local context = require("lvim-build.context")

---@param root string
---@return string
local function bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local r = tc.resolve("commonlisp", "sbcl", root)
        if r and r ~= "" then
            return r
        end
    end
    local p = vim.fn.exepath("sbcl")
    return p ~= "" and p or "sbcl"
end

---@type LvimBuildRecipe
return {
    name = "commonlisp",
    kind = "project",
    markers = { "*.asd" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "*.asd" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bin = bin(cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd }
        end
        return {
            act("asdf load-system", "Build", { bin, "--eval", "(asdf:load-system :app)", "--quit" }),
            act("asdf test-system", "Test", { bin, "--eval", "(asdf:test-system :app)", "--quit" }),
        }
    end,
}

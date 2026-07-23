-- lvim-build.recipes.toml: validate the current TOML file. taplo check / fmt --check.
-- Each action is added only when its checker is resolvable (PATH → Mason bin dir), so a project
-- with none installed simply offers nothing rather than a doomed command.
--
---@module "lvim-build.recipes.toml"

---@type table<string, boolean>
local FT = { toml = true }

--- Resolve a checker executable: PATH first, then the Mason bin dir. nil when absent.
---@param exe string
---@return string|nil
local function bin(exe)
    if vim.fn.executable(exe) == 1 then
        return exe
    end
    local mason = vim.fn.stdpath("data") .. "/mason/bin/" .. exe
    return vim.fn.executable(mason) == 1 and mason or nil
end

---@type LvimBuildRecipe
return {
    name = "toml",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if not FT[ctx.ft] or ctx.file == "" then
            return {}
        end
        local base = vim.fn.fnamemodify(ctx.file, ":t")
        local cwd = vim.fs.dirname(ctx.file)
        local out = {}
        local function add(exe, name, group, argv)
            local b = bin(exe)
            if b then
                argv[1] = b
                out[#out + 1] = { name = name, group = group, cmd = argv, cwd = cwd, matcher = "generic" }
            end
        end
        add("taplo", "taplo check " .. base, "Lint", { "taplo", "check", ctx.file })
        add("taplo", "taplo fmt --check " .. base, "Lint", { "taplo", "fmt", "--check", ctx.file })
        return out
    end,
}

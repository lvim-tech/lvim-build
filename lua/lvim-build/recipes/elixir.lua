-- lvim-build.recipes.elixir: an Elixir / mix project (mix.exs upward of the file/cwd).
-- Offers the standard mix verbs grouped Build / Run / Test / Lint: `mix compile`, `mix run`, the
-- ExUnit suite (`mix test`), `mix format`, and `mix credo` (static analysis). When lvim-lang is
-- installed and its Elixir provider is active, the `mix` binary is resolved through
-- `lvim-lang.core.toolchain` first (honouring the version manager / an explicit path), then PATH;
-- lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.elixir"

local context = require("lvim-build.context")

--- Resolve `mix`: the lvim-lang Elixir toolchain when active for `root`, else the bare name (found on
--- PATH at run time by lvim-tasks).
---@param root string
---@return string
local function mix_bin(root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("elixir", "mix", root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return "mix"
end

---@type LvimBuildRecipe
return {
    name = "elixir",
    kind = "project",
    markers = { "mix.exs" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "mix.exs")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local mix = mix_bin(cwd)
        local function act(name, group, tail)
            local argv = { mix }
            vim.list_extend(argv, tail)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = "generic" }
        end
        return {
            act("mix compile", "Build", { "compile" }),
            act("mix run", "Run", { "run" }),
            act("mix test", "Test", { "test" }),
            act("mix format", "Lint", { "format" }),
            act("mix credo", "Lint", { "credo", "--strict" }),
        }
    end,
}

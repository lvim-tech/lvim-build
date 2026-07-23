-- lvim-build.recipes.erlang: an Erlang project (rebar.config upward of the file/cwd).
-- Offers the standard rebar3 verbs grouped Build / Run / Test / Lint: compile the project, start the
-- interactive shell, run the EUnit and Common Test suites, and format the current file with erlfmt.
-- When lvim-lang is installed and its Erlang provider is active, the `rebar3` / `erlfmt` binaries are
-- resolved through `lvim-lang.core.toolchain` first (honouring the version manager / an explicit
-- path), then PATH; lvim-build works fully without lvim-lang. rebar3's compiler diagnostics
-- (`file.erl:Line:Col: message`) are parsed with the `generic` problem matcher.
--
---@module "lvim-build.recipes.erlang"

local context = require("lvim-build.context")

--- Resolve `tool` ("rebar3" | "erlfmt"): the lvim-lang Erlang toolchain when active for `root`, else
--- the bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("erlang", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "erlang",
    kind = "project",
    markers = { "rebar.config" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, "rebar.config")
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local rebar3 = bin("rebar3", cwd)
        local function act(name, group, argv)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = "generic" }
        end

        local actions = {
            act("rebar3 compile", "Build", { rebar3, "compile" }),
            act("rebar3 shell", "Run", { rebar3, "shell" }),
            act("rebar3 eunit", "Test", { rebar3, "eunit" }),
            act("rebar3 ct", "Test", { rebar3, "ct" }),
        }
        -- Format the current file with erlfmt when it is an Erlang buffer.
        if ctx.file ~= "" and ctx.file:match("%.erl$") then
            actions[#actions + 1] = act(
                "erlfmt " .. vim.fn.fnamemodify(ctx.file, ":t"),
                "Lint",
                { bin("erlfmt", cwd), "--write", ctx.file }
            )
        end
        return actions
    end,
}

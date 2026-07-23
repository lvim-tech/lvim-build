-- lvim-build.recipes.ruby: a Ruby project (Gemfile / Rakefile upward of the file/cwd).
-- Offers the standard Ruby verbs grouped Run / Test / Lint: run the current `.rb` file, run the
-- default `rake` task, run the RSpec suite, and lint with `rubocop`. Bundle-aware — when the project
-- has a Gemfile the rspec / rubocop / rake invocations go through `bundle exec` so they run against
-- the project's locked gems. When lvim-lang is installed and its Ruby provider is active, the
-- `ruby` / `bundle` binaries are resolved through `lvim-lang.core.toolchain` first (honouring the
-- version manager / an explicit path), then PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.ruby"

local context = require("lvim-build.context")

--- Resolve `tool` ("ruby" | "bundle" | "rspec" | "rubocop" | "rake"): the lvim-lang Ruby toolchain
--- when active for `root`, else the bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("ruby", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "ruby",
    kind = "project",
    markers = { "Gemfile", "Rakefile" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, { "Gemfile", "Rakefile" })
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local bundled = vim.fn.filereadable(vim.fs.joinpath(cwd, "Gemfile")) == 1
        local function act(name, group, argv, matcher)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = matcher }
        end
        -- `bundle exec <tool>` in a bundled project, else the tool directly.
        local function exec(tool, tail)
            local argv = bundled and { bin("bundle", cwd), "exec", tool } or { tool }
            vim.list_extend(argv, tail or {})
            return argv
        end

        local actions = {}
        -- Run the current file when it is a Ruby buffer.
        if ctx.file ~= "" and ctx.file:match("%.rb$") then
            local argv = bundled and { bin("bundle", cwd), "exec", "ruby", ctx.file } or { bin("ruby", cwd), ctx.file }
            actions[#actions + 1] = act("ruby " .. vim.fn.fnamemodify(ctx.file, ":t"), "Run", argv, "generic")
        end
        actions[#actions + 1] = act("rake", "Run", exec("rake"), "generic")
        actions[#actions + 1] = act("rspec", "Test", exec("rspec"), "generic")
        actions[#actions + 1] = act("rubocop", "Lint", exec("rubocop"), "generic")
        return actions
    end,
}

-- lvim-build.recipes.shell: run / syntax-check the current shell script. The interpreter follows
-- the shebang when there is one (a #!/bin/zsh script must not run under bash), the filetype
-- otherwise. `-n` is the interpreter's own no-exec syntax check — the Lint action.
--
---@module "lvim-build.recipes.shell"

local context = require("lvim-build.context")

---@type table<string, boolean>
local SHELL_FT = { sh = true, bash = true, zsh = true }

---@type LvimBuildRecipe
return {
    name = "shell",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if not SHELL_FT[ctx.ft] or ctx.file == "" then
            return {}
        end
        local interp = ctx.ft == "sh" and "sh" or ctx.ft
        local lines = context.readlines(ctx.file)
        local line1 = lines and lines[1] or ""
        local shebang = line1:match("^#!%s*(%S+)")
        if shebang then
            local tail = vim.fs.basename(shebang)
            interp = tail == "env" and (line1:match("env%s+(%S+)") or interp) or tail
        end
        local base = vim.fn.fnamemodify(ctx.file, ":t")
        local cwd = vim.fs.dirname(ctx.file)
        return {
            {
                name = interp .. " " .. base,
                group = "Run",
                cmd = { interp, ctx.file },
                cwd = cwd,
                matcher = "generic",
            },
            {
                name = interp .. " -n " .. base .. " (syntax)",
                group = "Lint",
                cmd = { interp, "-n", ctx.file },
                cwd = cwd,
                matcher = "generic",
            },
        }
    end,
}

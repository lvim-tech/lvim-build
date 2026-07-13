-- lvim-build.recipes.python_single: run the CURRENT Python buffer.
--
-- Unlike the compiled single-file fallbacks (c / cpp / rust_single), this one is NOT suppressed
-- inside a project: running the script you are looking at is normal Python workflow even in a
-- packaged project (a script, a scratch, a management command), whereas compiling one .c file of
-- a cargo/cmake project is not. It does, however, run through the PROJECT's interpreter when there
-- is one (its virtualenv / package manager — see recipes/python_env.lua), and from the project
-- ROOT, so imports resolve exactly as they do for the project's own actions. With no project it
-- falls back to the PATH interpreter, run from the file's own directory.
--
---@module "lvim-build.recipes.python_single"

local context = require("lvim-build.context")
local env_mod = require("lvim-build.recipes.python_env")

-- The files that mark a Python project (kept in step with recipes/python.lua's MARKERS).
local MARKERS = {
    "pyproject.toml",
    "manage.py",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "tox.ini",
    "noxfile.py",
}

---@type LvimBuildRecipe
return {
    name = "python_single",
    kind = "file",
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        if ctx.ft ~= "python" or ctx.file == "" then
            return {}
        end
        local marker = context.marker(ctx, MARKERS)
        local root = marker and vim.fs.dirname(marker) or vim.fs.dirname(ctx.file)
        local pyproject = marker and context.readlines(root .. "/pyproject.toml") or nil
        local env = env_mod.resolve(root, pyproject and table.concat(pyproject, "\n") or nil)
        local py = env_mod.python(env)
        return {
            {
                name = "python " .. vim.fn.fnamemodify(ctx.file, ":t") .. env_mod.origin(env, py),
                group = "Run",
                cmd = vim.list_extend(vim.list_extend({}, py), { ctx.file }),
                cwd = root,
                matcher = "python",
            },
        }
    end,
}

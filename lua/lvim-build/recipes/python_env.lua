-- lvim-build.recipes.python_env: WHICH python (and which pytest / ruff / mypy) a project's actions
-- must actually run — the piece that makes the Python recipes usable rather than merely plausible.
--
-- Python has no single canonical `cargo`-style entry point: a project's tools live in a virtualenv
-- (.venv/bin/pytest), or behind a package manager (`uv run pytest`, `poetry run pytest`, `pipenv
-- run`, `hatch run`), or — only sometimes — on the PATH. Emitting a bare `pytest` is therefore a
-- coin flip: it finds nothing, or it silently runs the WRONG interpreter's tool against the
-- project. So every Python action resolves its command through here, in this order:
--
--   1. the project's virtualenv       (.venv/ or venv/ next to the marker, or $VIRTUAL_ENV)
--   2. the package manager that owns the project  (uv / poetry / pipenv / hatch)
--   3. the PATH                       (a globally installed tool)
--
-- and an action whose tool resolves NOWHERE is not offered at all — the chooser never lists a
-- command that cannot run.
--
---@module "lvim-build.recipes.python_env"

local M = {}

-- A virtualenv's executable dir differs by platform (POSIX bin/, Windows Scripts/). Exported: the
-- recipe's cache `watch` stamps this dir's mtime — a tool installed into the venv lands there, and
-- that is exactly when a new action becomes available.
local BIN = (vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1) and "Scripts" or "bin"
M.BIN = BIN

-- Package managers that can RUN a project's tools, in precedence order. `lock` is the file that
-- proves the project uses it; `tool` is the pyproject `[tool.<x>]` table that also proves it.
local MANAGERS = {
    { cmd = "uv", lock = "uv.lock", tool = "uv" },
    { cmd = "poetry", lock = "poetry.lock", tool = "poetry" },
    { cmd = "pipenv", lock = "Pipfile", tool = nil },
    { cmd = "hatch", lock = nil, tool = "hatch" },
}

---@class LvimBuildPythonEnv
---@field root    string   the project dir the actions run in
---@field venv    string?  the project's virtualenv bin/Scripts dir, when there is one
---@field manager string?  the package manager that owns the project ("uv" / "poetry" / …)
---@field pyproject string? the pyproject.toml text, when the project has one (nil otherwise)

--- Is `path` an executable file?
---@param path string
---@return boolean
local function executable(path)
    return vim.fn.executable(path) == 1
end

--- The project's virtualenv bin dir: `.venv` / `venv` under `root`, else an ACTIVE $VIRTUAL_ENV
--- (the user activated one in the shell Neovim was launched from). nil when there is none.
---@param root string
---@return string?
local function find_venv(root)
    for _, name in ipairs({ ".venv", "venv" }) do
        local dir = root .. "/" .. name .. "/" .. BIN
        if vim.fn.isdirectory(dir) == 1 then
            return dir
        end
    end
    local active = vim.env.VIRTUAL_ENV
    if active and active ~= "" and vim.fn.isdirectory(active .. "/" .. BIN) == 1 then
        return active .. "/" .. BIN
    end
    return nil
end

--- Resolve the environment of the Python project rooted at `root`. `pyproject` is its
--- pyproject.toml TEXT when it has one (used to spot `[tool.uv]` / `[tool.poetry]` / …).
---@param root string
---@param pyproject string?
---@return LvimBuildPythonEnv
function M.resolve(root, pyproject)
    local manager
    for _, m in ipairs(MANAGERS) do
        -- The project must both USE the manager (a lockfile, or its [tool.x] table) and HAVE it
        -- installed — otherwise `uv run pytest` would just fail differently than bare `pytest`.
        local uses = (m.lock ~= nil and vim.fn.filereadable(root .. "/" .. m.lock) == 1)
            or (m.tool ~= nil and pyproject ~= nil and pyproject:find("[tool." .. m.tool .. "]", 1, true) ~= nil)
        if uses and executable(m.cmd) then
            manager = m.cmd
            break
        end
    end
    return { root = root, venv = find_venv(root), manager = manager, pyproject = pyproject }
end

--- The argv that runs `tool` (e.g. "pytest") in this environment, or nil when the tool is not
--- reachable at all — in which case its action must not be offered.
---@param env LvimBuildPythonEnv
---@param tool string
---@return string[]?
function M.cmd(env, tool)
    if env.venv then
        local path = env.venv .. "/" .. tool
        if executable(path) then
            return { path }
        end
    end
    if env.manager then
        -- A package manager provides the tool from the env it manages, whether or not that env
        -- has been materialised yet — so it is offered without probing for the binary.
        return { env.manager, "run", tool }
    end
    if executable(tool) then
        return { tool }
    end
    return nil
end

--- The argv that runs the project's PYTHON interpreter. Unlike a tool this ALWAYS resolves: the
--- venv's (which always ships `python`), the manager's, else the PATH's — `python3` FIRST there,
--- because a bare `python` is still Python 2 on some systems while `python3` never is.
---@param env LvimBuildPythonEnv
---@return string[]
function M.python(env)
    if env.venv then
        local path = env.venv .. "/python"
        if executable(path) then
            return { path }
        end
    end
    if env.manager then
        return { env.manager, "run", "python" }
    end
    return { executable("python3") and "python3" or "python" }
end

--- The argv that runs `-m <module>` with the project's interpreter (`python -m build`, `python -m
--- unittest`, …).
---@param env LvimBuildPythonEnv
---@param module string
---@param ... string  extra args
---@return string[]
function M.module(env, module, ...)
    local argv = vim.list_extend({}, M.python(env))
    vim.list_extend(argv, { "-m", module })
    return vim.list_extend(argv, { ... })
end

--- A short label for where a command comes from — shown in the action name so the chooser makes
--- the resolution VISIBLE ("pytest (.venv)" vs "pytest (uv)" vs "pytest").
---@param env LvimBuildPythonEnv
---@param argv string[]
---@return string
function M.origin(env, argv)
    if env.venv and argv[1] and argv[1]:sub(1, #env.venv) == env.venv then
        return " (venv)"
    end
    if env.manager and argv[1] == env.manager then
        return " (" .. env.manager .. ")"
    end
    return ""
end

return M

-- lvim-build.recipes.python: a Python project — test / lint / build / run actions, each resolved
-- through the project's actual environment (see recipes/python_env.lua).
--
-- A Python project is NOT just a pyproject.toml: setup.py, setup.cfg, requirements.txt, Pipfile,
-- tox.ini, noxfile.py and Django's manage.py all mark one, and each brings its own actions. An
-- action is offered only when the project is CONFIGURED for it (the tool is declared/config'd)
-- AND the tool RESOLVES (venv → package manager → PATH) — so the chooser never lists a command
-- that cannot run, and never runs a system-wide tool against a virtualenv'd project.
--
---@module "lvim-build.recipes.python"

local context = require("lvim-build.context")
local env_mod = require("lvim-build.recipes.python_env")

-- Every file that marks a Python project. The FIRST one found upward wins as the root anchor,
-- but all of them are consulted for actions (a project can have pyproject.toml AND manage.py).
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

--- Does `root` hold a file called `name`?
---@param root string
---@param name string
---@return boolean
local function has(root, name)
    return vim.fn.filereadable(root .. "/" .. name) == 1
end

--- Read `root/name` as one string, or nil.
---@param root string
---@param name string
---@return string?
local function read(root, name)
    local lines = context.readlines(root .. "/" .. name)
    return lines and table.concat(lines, "\n") or nil
end

--- Is `tool` configured for this project — named in pyproject/setup.cfg/tox.ini, or owning a
--- config file of its own? (A text scan, not a TOML parse: a tool is "configured" when it is a
--- dependency or a [tool.x] table, and both contain the word.)
---@param root string
---@param texts string[]  the project config texts already read
---@param tool string
---@param files string[]? config files that alone prove it
---@return boolean
local function configured(root, texts, tool, files)
    for _, f in ipairs(files or {}) do
        if has(root, f) then
            return true
        end
    end
    for _, t in ipairs(texts) do
        if t:find(tool, 1, true) then
            return true
        end
    end
    return false
end

-- What a Python project's ACTIONS depend on beyond its markers: the environment they resolve
-- through. `uv sync` / `python -m venv` / `uv add pytest` all change which actions exist while
-- touching no marker file — so without this the chooser would keep serving its pre-sync list.
-- (The venv's bin/ dir is where an installed tool lands, hence its mtime, not the venv root's.)
local WATCHED = {
    "uv.lock",
    "poetry.lock",
    "Pipfile.lock",
    "tests",
    ".venv/" .. env_mod.BIN,
    "venv/" .. env_mod.BIN,
}

---@type LvimBuildRecipe
return {
    name = "python",
    kind = "project",
    markers = MARKERS,
    ---@param ctx LvimBuildContext
    ---@return string
    watch = function(ctx)
        local marker = context.marker(ctx, MARKERS)
        if not marker then
            return ""
        end
        local root = vim.fs.dirname(marker)
        local parts = {}
        for _, p in ipairs(WATCHED) do
            -- mtime is 0 when the path is absent, so APPEARING changes the stamp too.
            parts[#parts + 1] = p .. "@" .. context.mtime(root .. "/" .. p)
        end
        return table.concat(parts, ",")
    end,
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = context.marker(ctx, MARKERS)
        if not marker then
            return {}
        end
        local root = vim.fs.dirname(marker)
        local pyproject = read(root, "pyproject.toml")
        local env = env_mod.resolve(root, pyproject)

        -- The texts a tool can be "configured" in.
        local texts = {}
        for _, t in ipairs({ pyproject, read(root, "setup.cfg"), read(root, "tox.ini") }) do
            texts[#texts + 1] = t
        end

        local out = {}
        --- Add an action for `tool` when it resolves; `args` follow the tool.
        ---@param tool string
        ---@param args string[]
        ---@param group string
        ---@param matcher string
        ---@param label string?  overrides the action name (before the origin suffix)
        local function tool_action(tool, args, group, matcher, label)
            local argv = env_mod.cmd(env, tool)
            if not argv then
                return
            end
            argv = vim.list_extend(vim.list_extend({}, argv), args)
            out[#out + 1] = {
                name = (label or (tool .. " " .. table.concat(args, " "))):gsub("%s+$", "")
                    .. env_mod.origin(env, argv),
                group = group,
                cmd = argv,
                cwd = root,
                matcher = matcher,
            }
        end

        -- ── Test ─────────────────────────────────────────────────────────────
        -- pytest when it is configured, or when there is simply a tests/ dir (the convention that
        -- needs no config at all). Its failures are NOT tracebacks (it prints its own
        -- `file:line: msg` footer), hence the `pytest` matcher, not `python`.
        local has_tests = vim.fn.isdirectory(root .. "/tests") == 1
        if configured(root, texts, "pytest", { "pytest.ini", "conftest.py" }) or has_tests then
            tool_action("pytest", {}, "Test", "pytest")
        end
        -- Without pytest, the stdlib runner still tests a tests/ dir.
        if has_tests and not env_mod.cmd(env, "pytest") then
            out[#out + 1] = {
                name = "unittest discover",
                group = "Test",
                cmd = env_mod.module(env, "unittest", "discover"),
                cwd = root,
                matcher = "python",
            }
        end
        if has(root, "tox.ini") then
            tool_action("tox", {}, "Test", "pytest")
        end
        if has(root, "noxfile.py") then
            tool_action("nox", {}, "Test", "pytest")
        end

        -- ── Lint ─────────────────────────────────────────────────────────────
        -- ruff/mypy/black/flake8 emit `file:line:col: msg` → the `generic` matcher.
        if configured(root, texts, "ruff", { "ruff.toml", ".ruff.toml" }) then
            tool_action("ruff", { "check", "." }, "Lint", "generic")
            tool_action("ruff", { "format", "." }, "Lint", "generic")
        end
        if configured(root, texts, "mypy", { "mypy.ini", ".mypy.ini" }) then
            tool_action("mypy", { "." }, "Lint", "generic")
        end
        if configured(root, texts, "black", {}) then
            tool_action("black", { "." }, "Lint", "generic")
        end
        if configured(root, texts, "flake8", { ".flake8" }) then
            tool_action("flake8", {}, "Lint", "generic")
        end

        -- ── Build / deps ─────────────────────────────────────────────────────
        -- The manager's own build when it owns the project, else PEP 517 via `python -m build`
        -- (offered only when the project declares a build backend).
        if env.manager == "uv" or env.manager == "poetry" or env.manager == "hatch" then
            out[#out + 1] = {
                name = env.manager .. " build",
                group = "Build",
                cmd = { env.manager, "build" },
                cwd = root,
                matcher = "generic",
            }
        elseif pyproject and pyproject:find("[build-system]", 1, true) and env_mod.cmd(env, "pyproject-build") then
            -- `python -m build` needs the `build` PACKAGE installed — a declared [build-system] only
            -- says how the project WOULD be built. `build` ships the `pyproject-build` entry point,
            -- so resolving that is the cheap proof the module is actually there (no probe process).
            out[#out + 1] = {
                name = "python -m build",
                group = "Build",
                cmd = env_mod.module(env, "build"),
                cwd = root,
                matcher = "generic",
            }
        end
        -- Install the pinned dependencies — the action a fresh clone needs first.
        if has(root, "requirements.txt") then
            if env.manager == "uv" then
                out[#out + 1] = {
                    name = "uv pip install -r requirements.txt",
                    group = "Build",
                    cmd = { "uv", "pip", "install", "-r", "requirements.txt" },
                    cwd = root,
                    matcher = "generic",
                }
            else
                out[#out + 1] = {
                    name = "pip install -r requirements.txt",
                    group = "Build",
                    cmd = env_mod.module(env, "pip", "install", "-r", "requirements.txt"),
                    cwd = root,
                    matcher = "generic",
                }
            end
        end
        -- `uv sync` MATERIALISES the environment (.venv + uv.lock). Offer it when uv owns the
        -- project — and also when a pyproject project has NO environment yet and no other manager
        -- claims it: a fresh `uv init` has neither a lockfile nor a [tool.uv] table, so nothing is
        -- runnable and the chooser would otherwise sit empty. It stays an EXPLICIT action (uv is
        -- never silently adopted as the runner); once it has run, the .venv it creates is what every
        -- other tool then resolves through.
        local uv_bootstrap = env.manager == nil
            and pyproject ~= nil
            and env.venv == nil
            and vim.fn.executable("uv") == 1
        if env.manager == "uv" or uv_bootstrap then
            out[#out + 1] =
                { name = "uv sync", group = "Build", cmd = { "uv", "sync" }, cwd = root, matcher = "generic" }
        end

        -- ── Run (Django) ─────────────────────────────────────────────────────
        -- manage.py is the project's entry point: its runserver and test are the two actions a
        -- Django project is actually driven by.
        if has(root, "manage.py") then
            local py = env_mod.python(env)
            out[#out + 1] = {
                name = "manage.py runserver" .. env_mod.origin(env, py),
                group = "Run",
                cmd = vim.list_extend(vim.list_extend({}, py), { "manage.py", "runserver" }),
                cwd = root,
                matcher = "python",
            }
            out[#out + 1] = {
                name = "manage.py test" .. env_mod.origin(env, py),
                group = "Test",
                cmd = vim.list_extend(vim.list_extend({}, py), { "manage.py", "test" }),
                cwd = root,
                -- Django's test runner prints tracebacks AND `file:line: msg` footers → pytest efm
                -- covers both; the plain `python` one would miss the footers.
                matcher = "pytest",
            }
        end

        return out
    end,
}

-- lvim-build.recipes.fsharp: an F# / .NET project (a `*.fsproj` project upward of the file/cwd) —
-- the standard `dotnet` verbs grouped Build / Run / Test, plus Fantomas formatting when it is
-- available.
--
-- `.fsproj` is a GLOB, not a literal marker NAME, so the root is found by a directory SCAN (a
-- `vim.fs.find` with a predicate, upward from the file) rather than `context.marker`. That means the
-- marker-mtime cache stamp cannot see it, so a `watch` reports the nearest project file + its mtime —
-- mirroring how the dotnet recipe watches its solution/project. Keyed on `.fsproj` (not `.sln`) so it
-- does not double up with the `dotnet` recipe on a pure C# solution; a mixed F#/C# solution simply
-- gets both recipes' actions.
--
-- When lvim-lang is installed and its F# provider is active, the `dotnet` / `fantomas` binary is
-- resolved through `lvim-lang.core.toolchain` first (honouring a version-managed SDK), then PATH;
-- lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.fsharp"

local context = require("lvim-build.context")

--- Find the nearest `*.fsproj` UPWARD from the context's file (or the cwd). Returns the absolute
--- marker path, or nil.
---@param ctx LvimBuildContext
---@return string?
local function find_marker(ctx)
    local start = ctx.file ~= "" and vim.fs.dirname(ctx.file) or vim.fn.getcwd()
    local found = vim.fs.find(function(name)
        return name:match("%.fsproj$") ~= nil
    end, { upward = true, path = start, limit = 8 })
    if #found == 0 then
        return nil
    end
    return vim.fs.normalize(found[1])
end

--- Resolve `tool` ("dotnet" | "fantomas"): the lvim-lang F# toolchain when active for `root`, else
--- the bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("fsharp", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "fsharp",
    kind = "project",
    -- No literal markers (the roots are globs); the watch below supplies the cache stamp instead.
    markers = {},
    ---@param ctx LvimBuildContext
    ---@return string
    watch = function(ctx)
        local marker = find_marker(ctx)
        if not marker then
            return ""
        end
        return marker .. "@" .. context.mtime(marker)
    end,
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        local marker = find_marker(ctx)
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local dotnet = bin("dotnet", cwd)
        local function act(name, group, argv)
            -- The F# compiler emits `file(line,col): error FSxxxx: msg`, matched by the `typescript`
            -- problem matcher shape (`%f(%l,%c): … %m`).
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = "typescript" }
        end

        local actions = {
            act("dotnet build", "Build", { dotnet, "build" }),
            act("dotnet build -c Release", "Build", { dotnet, "build", "-c", "Release" }),
            act("dotnet run", "Run", { dotnet, "run" }),
            act("dotnet test", "Test", { dotnet, "test" }),
            act("dotnet restore", "Build", { dotnet, "restore" }),
        }

        -- Offer Fantomas formatting only when it actually resolves (a mason install / PATH).
        local fantomas = bin("fantomas", cwd)
        if fantomas ~= "fantomas" or vim.fn.executable("fantomas") == 1 then
            actions[#actions + 1] = { name = "fantomas format", group = "Lint", cmd = { fantomas, "." }, cwd = cwd }
        end

        return actions
    end,
}

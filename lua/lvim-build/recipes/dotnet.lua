-- lvim-build.recipes.dotnet: a .NET project (a `*.sln` solution or a `*.csproj` project upward of
-- the file/cwd) — the standard `dotnet` verbs grouped Build / Run / Test, plus csharpier formatting
-- when it is available.
--
-- `.sln` / `.csproj` are GLOBS, not literal marker NAMES, so the root is found by a directory SCAN
-- (a `vim.fs.find` with a predicate, upward from the file) rather than `context.marker`. That means
-- the marker-mtime cache stamp cannot see it, so a `watch` reports the nearest solution/project file
-- + its mtime — mirroring how the python recipe watches its environment.
--
-- When lvim-lang is installed and its C# provider is active, the `dotnet` / `csharpier` binary is
-- resolved through `lvim-lang.core.toolchain` first (honouring a version-managed SDK), then PATH;
-- lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.dotnet"

local context = require("lvim-build.context")

--- Find the nearest `*.sln` or `*.csproj` UPWARD from the context's file (or the cwd), preferring a
--- solution when one sits at the same level. Returns the absolute marker path, or nil.
---@param ctx LvimBuildContext
---@return string?
local function find_marker(ctx)
    local start = ctx.file ~= "" and vim.fs.dirname(ctx.file) or vim.fn.getcwd()
    local found = vim.fs.find(function(name)
        return name:match("%.sln$") ~= nil or name:match("%.csproj$") ~= nil
    end, { upward = true, path = start, limit = 8 })
    if #found == 0 then
        return nil
    end
    -- Prefer a solution when several markers were found at the nearest levels.
    for _, p in ipairs(found) do
        if p:match("%.sln$") then
            return vim.fs.normalize(p)
        end
    end
    return vim.fs.normalize(found[1])
end

--- Resolve `tool` ("dotnet" | "csharpier"): the lvim-lang C# toolchain when active for `root`, else
--- the bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    -- lvim-lang resolves the language-server binary under the exact case "OmniSharp"; the CLI tools
    -- (dotnet / csharpier) resolve under their own names.
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("csharp", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

---@type LvimBuildRecipe
return {
    name = "dotnet",
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
            -- The C# compiler emits `file(line,col): error CSxxxx: msg`, matched by the `typescript`
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

        -- Offer csharpier formatting only when it actually resolves (a mason install / PATH).
        local csharpier = bin("csharpier", cwd)
        if csharpier ~= "csharpier" or vim.fn.executable("csharpier") == 1 then
            actions[#actions + 1] =
                { name = "csharpier format", group = "Lint", cmd = { csharpier, "format", "." }, cwd = cwd }
        end

        return actions
    end,
}

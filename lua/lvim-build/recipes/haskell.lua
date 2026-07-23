-- lvim-build.recipes.haskell: a Haskell project driven by Stack or Cabal — build / run / test through
-- whichever build tool the project uses, plus fourmolu (format) and hlint (lint). Detection walks up
-- from the file for a `stack.yaml` (→ Stack) or a `cabal.project` / any `*.cabal` package file
-- (→ Cabal); Stack is preferred when both are present (the tool the author committed to). GHC emits
-- `File.hs:line:col: error: message` diagnostics, routed to the quickfix by the `haskell` errorformat.
-- When lvim-lang is installed and its Haskell provider is active, each binary (stack / cabal / fourmolu
-- / hlint) is resolved through `lvim-lang.core.toolchain` first (honouring GHCup / a version manager),
-- then PATH; lvim-build works fully without lvim-lang.
--
---@module "lvim-build.recipes.haskell"

local context = require("lvim-build.context")

-- GHC diagnostics: `File.hs:line:col: error:` / `…: warning:` (and the `-ferror-spans` range forms),
-- the indented lines that follow carrying the message. `%t%*[^:]` reads the severity char then the
-- rest up to the colon. Passed to lvim-tasks as a literal errorformat (multi-line bodies best-effort).
local HASKELL_EFM = table.concat({
    [[%E%f:%l:%c: error:]],
    [[%W%f:%l:%c: warning:]],
    [[%E%f:%l:%c-%*[0-9]: error:]],
    [[%W%f:%l:%c-%*[0-9]: warning:]],
    [[%E%f:(%l\,%c)-(%*[0-9]\,%*[0-9]): error:]],
    [[%W%f:(%l\,%c)-(%*[0-9]\,%*[0-9]): warning:]],
    [[%C    %m]],
    [[%C  %m]],
    [[%-G%.%#]],
}, ",")

--- Resolve a tool ("stack" | "cabal" | "fourmolu" | "hlint"): the lvim-lang Haskell toolchain when
--- active for `root`, else the bare name (found on PATH at run time by lvim-tasks).
---@param tool string
---@param root string
---@return string
local function bin(tool, root)
    local ok, tc = pcall(require, "lvim-lang.core.toolchain")
    if ok and tc and tc.resolve then
        local resolved = tc.resolve("haskell", tool, root)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return tool
end

--- The build tool for a project dir: "stack" (a `stack.yaml`) → "cabal" (a `cabal.project` /
--- `*.cabal`) → nil. Stack is checked first so a project shipping both prefers Stack.
---@param dir string
---@return "stack"|"cabal"|nil
local function detect_tool(dir)
    if vim.fn.filereadable(vim.fs.joinpath(dir, "stack.yaml")) == 1 then
        return "stack"
    end
    if
        vim.fn.filereadable(vim.fs.joinpath(dir, "cabal.project")) == 1
        or #vim.fn.glob(vim.fs.joinpath(dir, "*.cabal"), true, true) > 0
    then
        return "cabal"
    end
    return nil
end

---@type LvimBuildRecipe
return {
    name = "haskell",
    kind = "project",
    markers = { "stack.yaml", "cabal.project", "package.yaml" },
    ---@param ctx LvimBuildContext
    ---@return LvimBuildAction[]
    detect = function(ctx)
        -- Find the project dir: the nearest fixed marker, or any `*.cabal` upward from the file.
        local marker = context.marker(ctx, { "stack.yaml", "cabal.project", "package.yaml" })
        if not marker then
            local start = ctx.file ~= "" and vim.fs.dirname(ctx.file) or vim.fn.getcwd()
            local cabal = vim.fs.find(function(name)
                return name:match("%.cabal$") ~= nil
            end, { upward = true, path = start, limit = 1 })[1]
            marker = cabal and vim.fs.normalize(cabal) or nil
        end
        if not marker then
            return {}
        end
        local cwd = vim.fs.dirname(marker)
        local tool = detect_tool(cwd)
        if not tool then
            return {}
        end
        local hs = bin(tool, cwd)
        local function act(name, group, argv, matcher)
            return { name = name, group = group, cmd = argv, cwd = cwd, matcher = matcher }
        end
        return {
            act(tool .. " build", "Build", { hs, "build" }, HASKELL_EFM),
            act(tool .. " run", "Run", { hs, "run" }, HASKELL_EFM),
            act(tool .. " test", "Test", { hs, "test" }, HASKELL_EFM),
            act("fourmolu --mode inplace .", "Lint", { bin("fourmolu", cwd), "--mode", "inplace", "." }),
            act("hlint .", "Lint", { bin("hlint", cwd), "." }),
        }
    end,
}
